# frozen_string_literal: true

require 'sequel'
require 'forwardable'

module Tzispa
  module Data

    class AdapterPool
      include Enumerable
      extend Forwardable

      def_delegators :@pool, :has_key?, :keys
      attr_reader :default

      def initialize(config, default = nil)
        setup_sequel
        @default = default || config.first[0]
        @pool = {}.tap do |hsh|
          config.each do |k, v|
            conn = Sequel.connect "#{v.adapter}://#{v.database}"
            if v.connection_validation
              conn.extension(:connection_validator)
              conn.pool.connection_validation_timeout = v.validation_timeout || DEFAULT_TIMEOUT
            end
            hsh[k.to_sym] = conn
          end
        end
      end

      def [](name = nil)
        @pool[name&.to_sym || default]
      end

      def setup_sequel
        Sequel.extension :core_extensions
        Sequel.default_timezone = :utc
        Sequel.datetime_class = DateTime
      end

      DEFAULT_TIMEOUT = 3600
    end

  end
end
