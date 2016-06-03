require 'sequel'
require 'sequel/connection_pool/threaded'
require 'forwardable'

module Tzispa
  module Data

    class AdapterPool
      include Enumerable
      extend Forwardable

      def_delegators :@pool, :has_key?, :keys
      attr_reader :default

      def initialize(config, default=nil)
        Sequel.default_timezone = :utc
        Sequel.datetime_class = DateTime
        Sequel.extension :core_extensions
        @default = default || config.first[0].to_sym
        @pool = Hash.new.tap { |hpool|
          config.each { |key, value|
            conn = Sequel.connect value.adapter, :pool_class => Sequel::ThreadedConnectionPool
            if value.connection_validation
              conn.extension(:connection_validator)
              conn.pool.connection_validation_timeout = value.connection_validation_timeout
            end
            hpool[key.to_sym] = conn
          }
        }
      end

      def [](name=nil)
        @pool[name&.to_sym || default]
      end

    end

  end
end
