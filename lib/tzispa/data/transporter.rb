# frozen_string_literal: true

module Tzispa
  module Data

    class Transporter

      DEFAULT_ENCODING       = 'ASCII-8BIT'
      DEFAULT_BUFFER_SIZE    = 2048
      DEFAULT_LINE_SEPARATOR = "\n"

      attr_reader :filename, :buffer_size, :encoding, :line_separator, :data_separator, :line_size, :strip, :check_count, :lines, :errors

      def initialize(fn, options = {})
        @filename = fn
        @buffer_size = options[:buffer_size] || DEFAULT_BUFFER_SIZE
        @encoding = options[:encoding] || DEFAULT_ENCODING
        @line_separator = options[:line_separator] || DEFAULT_LINE_SEPARATOR
        @line_size = options[:line_size]
        @data_separator = options[:data_separator]
        @strip = options[:strip]
        @check_count = options[:check_count]
        @errors = Array.new
      end

      def exist?
        File.exist? filename
      end

      def import(dataset, columns)
        lines = 0
        errors.clear
        buffer = Array.new
        File.open(filename, "rb:#{encoding}") { |fh|
          while line = read_line(fh, lines)
            lines += 1
            values = block_given? ? yield(line) : line.split(data_separator)
            raise TransporterBadFormat.new("Bad file format at line #{lines}: columns number does not match with values") unless values.count == columns.count
            buffer << values
            flush_data(dataset, columns, buffer) if lines % buffer_size == 0
          end
          flush_data dataset, columns, buffer
        }
        ds_count = dataset.count
        raise TransporterRecordCount.new ("Lines count (#{lines}) and records count (#{ds_count}) does not match") if check_count && lines != ds_count
        [lines, ds_count]
      end

      def export(data, append = false, &block)
        count = 0
        File.open(filename, append ? "ab:#{encoding}" : "wb:#{encoding}") { |fh|
          lock(fh, File::LOCK_EX) { |lfh|
            if data.is_a? Hash
              lfh << build_line(data, &block)
              count +=  1
            else
              data.each { |row|
                lfh << build_line(row, &block)
                count +=  1
              }
            end
          }
        }
        count
      end

      private

      def build_line(data, &block)
        String.new(block_given? ? yield(data) : data.values.join(data_separator)).tap { |line|
          line << line_separator
        }
      end

      def read_line(fh, lines)
        if line_size
          fh.read(line_size).tap { |record|
            res = fh.gets(line_separator) if strip && !fh.eof?
            raise TransporterBadFormat.new("Bad file format at line #{lines+1}") unless res.nil? || res.strip.empty?
          } unless fh.eof?
        else
          fh.gets(line_separator).tap { |line|
            line.rstrip! if strip
          } unless fh.eof?
        end
      end

      def flush_data(dataset, columns, buffer)
        begin
          dataset.import(columns, buffer)
          buffer.clear
        rescue
          insert_by_row(dataset, columns, buffer)
        end
      end

      def insert_by_row(dataset, columns, buffer)
        begin
          buffer.each { |row|
            begin
              dataset.insert columns, row
            rescue => err
              errors << "#{err} in #{row.inspect}\n#{err.backtrace&.join("\n")}"
            end
          }
        ensure
          buffer.clear
        end
      end

      def lock(file, mode)
  	    if file.flock(mode)
  	      begin
  	        yield file
  	      ensure
  	        file.flock(File::LOCK_UN)
  	      end
  	    end
      end


    end

    class TransporterError < StandardError; end
    class TransporterBadFormat < TransporterError; end
    class TransporterRecordCount < TransporterError; end


  end
end
