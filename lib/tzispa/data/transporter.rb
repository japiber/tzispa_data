# frozen_string_literal: true

module Tzispa
  module Data

    class Transporter
      DEFAULT_ENCODING       = 'ASCII-8BIT'
      DEFAULT_BUFFER_SIZE    = 2048
      DEFAULT_LINE_SEPARATOR = "\n"

      attr_reader :filename, :buffer_size, :encoding, :line_separator, :data_separator,
                  :line_size, :strip, :check_count, :lines, :errors

      def initialize(fn, options = {})
        @filename = fn
        @buffer_size = options[:buffer_size] || DEFAULT_BUFFER_SIZE
        @encoding = options[:encoding] || DEFAULT_ENCODING
        @line_separator = options[:line_separator] || DEFAULT_LINE_SEPARATOR
        @line_size = options[:line_size]
        @data_separator = options[:data_separator]
        @strip = options[:strip]
        @check_count = options[:check_count]
        @errors = []
      end

      def exist?
        File.exist? filename
      end

      def import(dataset, columns)
        errors.clear
        File.open(filename, "rb:#{encoding}") do |fh|
          lines = process_file_import fh, dataset, columns
          ds_count = dataset.count
          raise TransporterRecordCount.new(lines, ds_count) if check_count && lines != ds_count
          [lines, ds_count]
        end
      end

      def export(data, append = false, &block)
        count = 0
        File.open(filename, append ? "ab:#{encoding}" : "wb:#{encoding}") do |fh|
          lock(fh, File::LOCK_EX) do |lfh|
            if data.is_a? Hash
              lfh << build_line(data, &block)
              count += 1
            else
              data.each do |row|
                lfh << build_line(row, &block)
                count += 1
              end
            end
          end
        end
        count
      end

      private

      def process_file_import(fh, dataset, columns)
        while (line = read_line(fh, lines))
          lines = (lines || 0) + 1
          values = block_given? ? yield(line) : line.split(data_separator)
          columns? lines, values.count
          (buffer ||= []) << values
          flush_data(dataset, columns, buffer)
        end
        flush_data dataset, columns, buffer, true
        lines
      end

      def build_line(data)
        String.new(block_given? ? yield(data) : data.values.join(data_separator)).tap do |line|
          line << line_separator
        end
      end

      def read_line(fh, lines)
        return if fh.eof?
        if line_size
          fh.read(line_size).tap { separator? fh, lines + 1 }
        else
          fh.gets(line_separator).tap { |line| line.rstrip! if strip }
        end
      end

      def flush_data(dataset, columns, buffer, force = false)
        return unless (buffer.count % buffer_size).zero? || force
        dataset.import(columns, buffer)
        buffer.clear
      rescue
        insert_by_row(dataset, columns, buffer)
      end

      def insert_by_row(dataset, columns, buffer)
        buffer.each do |row|
          begin
            dataset.insert columns, row
          rescue => err
            errors << "#{err} in #{row.inspect}\n#{err.backtrace&.join("\n")}"
          end
        end
      ensure
        buffer.clear
      end

      def lock(file, mode)
        return unless file.flock(mode)
        begin
          yield file
        ensure
          file.flock(File::LOCK_UN)
        end
      end

      def separator?(fh, line)
        res = fh.gets(line_separator) if strip && !fh.eof?
        raise TransporterBadFormat.new(line) unless res.nil? || res.strip.empty?
      end

      def columns?(line, cols)
        raise TransporterBadFormat.new(line) unless cols == columns.count
      end
    end

    class TransporterError < StandardError; end

    class TransporterBadFormat < TransporterError
      def initialize(line)
        super "Bad file format at line #{line}: columns number does not match"
      end
    end

    class TransporterRecordCount < TransporterError
      def initialize(lines, count)
        super "Lines count (#{lines}) and records count (#{count}) does not match"
      end
    end

  end
end
