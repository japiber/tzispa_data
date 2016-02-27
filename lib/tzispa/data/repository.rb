# frozen_string_literal: true

require 'sequel'
require 'tzispa/utils/string'
require 'tzispa/data/adapter_pool'

module Tzispa
  module Data

    class DataError < StandardError; end;
    class UnknownAdapter < DataError; end;
    class UnknownModel < DataError; end;


    class Repository

      attr_reader :root, :selected_adapter

      LOCAL_REPO_ROOT = :repository

      def initialize(config, root = LOCAL_REPO_ROOT)
        @config = config
        @root = root
        @pool = Hash.new
        @adapters = AdapterPool.new config
        @selected_adapter = @adapters.default
      end

      def use(repo_id)
        raise UnknownAdapter.new("The '#{adapter}' adapter does not exists") unless @adapters.has_key? repo_id
        @selected_adapter = repo_id
      end

      def [](model)
        raise UnknownModel.new("The '#{model}' model does not exists in the adapter '#{selected_adapter}'") unless @pool.has_key? self.class.key(model, selected_adapter)
        @pool[self.class.key(model.to_sym, selected_adapter)]
      end

      def load!
        @config.each { |id, cfg|
          Mutex.new.synchronize {
            Sequel::Model.db = @adapters[id]
            if cfg.local
              build_local_repo id, cfg
            else
              require cfg.gem
              repo_mod, build_method = cfg.register.split('#')
              (TzString.constantize repo_mod).send build_method, self, id, cfg
            end
          }
        }
        self
      end

      def register(model_id, model_class, repo_id, config)
        model_class.db = @adapters[repo_id]
        config.extensions.split(',').each { |ext|
          model_class.db.extension ext.to_sym
        } if config.respond_to? :extensions
        @pool[self.class.key(model_id, repo_id)] = model_class
      end

      private

      def build_local_repo(repo_id, config)
        Dir["./#{root.to_s.downcase}/#{repo_id}/*.rb"].each { |file|
          model_id = file.split('/').last.split('.').first
          require local_model_source(model_id, repo_id)
          model_class = TzString.constantize "Repository::#{TzString.camelize repo_id}::#{TzString.camelize model_id}"
          register model_id, model_class, repo_id, config
        }
      end

      def local_model_source(model, repo_id)
        "./#{root.to_s.downcase}/#{repo_id}/#{model}"
      end

      def self.key(model_id, repo_id)
        "#{model_id}@#{repo_id}".to_sym
      end

    end

  end
end
