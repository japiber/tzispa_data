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
              build_local_repo id, cfg
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

      def build_local_repo(repo_id, config)
        Dir["./#{root.to_s.downcase}/#{repo_id}/*.rb"].each { |file|
          model_id = file.split('/').last.split('.').first
          require local_model_source(model_id, repo_id)
          model_class = "Repository::#{repo_id.camelize}::#{model_id.camelize}".constantize
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
