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
        @default = default || config.first[0]
        @pool = {}.tap do |hsh|
          config.each { |k, v| hsh[k.to_sym] = Sequel.connect "#{v.adapter}://#{v.database}" }
        end
        Sequel.default_timezone = :utc
        Sequel.datetime_class = DateTime
      end

      def [](name = nil)
        @pool[name&.to_sym || default]
      end
    end

  end
end
