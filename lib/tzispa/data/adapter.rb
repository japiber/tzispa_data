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
        Sequel.default_timezone = :utc
        Sequel.datetime_class = DateTime
        Sequel.extension :core_extensions
        @default = default || config.first[0].to_sym
        @pool = Hash.new.tap { |hpool|
          config.each { |key, value|
            hpool[key.to_sym] = Sequel.connect value.adapter
          }
        }
      end

      def [](name=nil)
        @pool[name&.to_sym || default]
      end

    end

  end
end
