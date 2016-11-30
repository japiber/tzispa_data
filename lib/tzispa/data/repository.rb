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

      using Tzispa::Utils

      attr_reader :root, :adapters

      LOCAL_REPO_ROOT = :repository

      def initialize(config, root = LOCAL_REPO_ROOT)
        @config = config
        @root = root
        @pool = Hash.new
        @adapters = AdapterPool.new config
      end

      def [](model, repo_id=nil)
        selected_repo = repo_id || @adapters.default
        raise UnknownModel.new("The '#{model}' model does not exists in the adapter '#{selected_repo}'") unless @pool.has_key? self.class.key(model, selected_repo)
        @pool[self.class.key(model.to_sym, selected_repo)]
      end

      def load!
        @config.each { |id, cfg|
          Mutex.new.synchronize {
            Sequel::Model.db = @adapters[id]
            if cfg.local
              load_local_helpers id, cfg
              load_local_models id, cfg
            else
              require cfg.gem
              self.class.include "Repository::#{id.to_s.camelize}".constantize
              self.class.send "load_#{id}", self, id, cfg
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

      def load_local_models(repo_id, config)
        models_path = "./#{root}/#{repo_id}/model"
        Dir["#{models_path}/*.rb"].each { |file|
          model_id = file.split('/').last.split('.').first
          require "#{models_path}/#{model_id}"
          model_class = "Repository::#{repo_id.to_s.camelize}::Model::#{model_id.camelize}".constantize
          register model_id, model_class, repo_id, config
        }
      end

      def load_local_helpers(repo_id, config)
        helpers_path = "./#{root}/#{repo_id}/helpers"
        Dir["#{helpers_path}/*.rb"].each { |file|
          helper_id = file.split('/').last.split('.').first
          require "#{helpers_path}/#{helper_id}"
        }
      end

      def self.key(model_id, repo_id)
        "#{model_id}@#{repo_id}".to_sym
      end

    end

  end
end
