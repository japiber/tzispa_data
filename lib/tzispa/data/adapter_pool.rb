# frozen_string_literal: true

require 'sequel'
require 'forwardable'

module Tzispa
  module Data

    class AdapterPool
      include Enumerable
      extend Forwardable

      def_delegators :@pool, :has_key?, :keys
      attr_reader :default_repo

      def initialize(config, default = nil)
        setup_sequel
        @default_repo = default || config.first[0]
        @pool = {}.tap do |hsh|
          config.each { |kid, vc| hsh[kid.to_sym] = connect(vc) }
        end
      end

      def connect(config)
        Sequel.connect("#{config.adapter}://#{config.database}").tap do |conn|
          if config.connection_validation
            conn.extension(:connection_validator)
            conn.pool.connection_validation_timeout = config.validation_timeout || DEFAULT_TIMEOUT
          end
          if config.respond_to? :extensions
            config.extensions.split(',').each { |ext| conn.extension ext.to_sym }
          end
        end
      end

      def [](name = nil)
        @pool[name&.to_sym || default_repo]
      end

      def default
        @pool[default_repo]
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
