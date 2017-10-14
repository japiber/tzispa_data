# frozen_string_literal: true

require 'tzispa_utils'

module Tzispa
  module Data
    module Entity

      def self.included(base)
        base.extend(ClassMethods)
      end

      def entity!
        @__entity || @__entity = self.class.entity_class.new(self)
      end

      module ClassMethods
        using Tzispa::Utils::TzString

        def entity_class
          if class_variable_defined? :@@__entity_class
            class_variable_get :@@__entity_class
          else
            class_variable_set :@@__entity_class,
                               name.sub('::Model', '::Entity').constantize
          end
        end
        alias entity entity_class
      end

    end
  end
end
