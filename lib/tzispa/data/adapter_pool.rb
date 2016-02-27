require 'sequel'
require 'forwardable'

module Tzispa
  module Data

    class AdapterPool
      include Enumerable
      extend Forwardable

      def_delegators :@pool, :has_key?, :keys
      attr_reader :default

      def initialize(config, default=nil)
        @default = default || config.first[0].to_sym
        @pool = Hash.new.tap { |hash|
          config.each { |key, value|
            hash[key.to_sym] = Sequel.connect value.adapter
          }
        }
        #@adapter_keys = @adapters.keys
        Sequel.default_timezone = :utc
        Sequel.datetime_class = DateTime
      end

      def [](name=nil)
        @pool[name&.to_sym || default]
      end

    end

  end
end
