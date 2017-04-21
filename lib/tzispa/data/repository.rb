# frozen_string_literal: true

require 'sequel'
require 'redis'
require 'tzispa/utils/string'
require 'tzispa/data/adapter_pool'

module Tzispa
  module Data

    class DataError < StandardError; end

    class UnknownAdapter < DataError
      def initialize(model, repo)
        "The '#{model}' model does not exists in the adapter '#{repo}'"
      end
    end

    class UnknownModel < DataError; end

    class Repository
      using Tzispa::Utils::TzString

      attr_reader :root, :adapters

      LOCAL_REPO_ROOT = :repository

      DEFAULT_CACHE_TTL = 900

      class << self
        def cache_client
          @cache_client ||= Redis.new(host: 'localhost')
        end
      end

      def initialize(config, root = nil)
        @config = config
        @root = root || LOCAL_REPO_ROOT
        @pool = {}
        @adapters = AdapterPool.new config
      end

      def [](model, repo_id = nil)
        selected_repo = repo_id || adapters.default_repo
        raise UnknownModel.new(model, selected_repo) unless pool.key?(selected_repo) &&
                                                            pool[selected_repo].key?(model.to_sym)
        pool[selected_repo][model.to_sym]
      end

      def models(repo_id = nil)
        pool[repo_id || adapters.default_repo].values
      end

      def module_const(repo_id = nil)
        selected_repo = repo_id || adapters.default_repo
        pool[selected_repo][:__repository_module] ||= repository_module(selected_repo)
      end

      def load!(domain)
        @config.each do |id, cfg|
          Mutex.new.synchronize do
            pool[id] = {}
            Sequel::Model.db = adapters[id]
            load_config_repo(id, cfg)
            domain.include module_const(id)
          end
        end
        self
      end

      def register(model_id, model_class, repo_id, config)
        model_class.db = @adapters[repo_id]
        if config.caching
          model_class.plugin :caching, self.class.cache_client,
                             ttl: config.ttl || DEFAULT_CACHE_TTL
        end
        @pool[repo_id][model_id.to_sym] = model_class
      end

      private

      attr_reader :pool

      def repository_module(repo_id)
        rm = @pool[repo_id].first[1].name.split('::')
        rm.pop
        rm.join('::').constantize
      end

      def load_config_repo(id, cfg)
        if cfg.local
          load_local_helpers id
          load_local_models id, cfg
          load_local_entities id
        else
          require cfg.gem
          repo_module = id.to_s.camelize.constantize
          self.class.include repo_module
          self.class.send "load_#{id}", self, id, cfg
        end
      end

      def load_local_models(repo_id, config)
        models_path = "./#{root}/#{repo_id}/model"
        repo_module = "#{repo_id.to_s.camelize}::Model".constantize
        Dir["#{models_path}/*.rb"].each do |file|
          model_id = file.split('/').last.split('.').first
          require "#{models_path}/#{model_id}"
          model_class = "#{repo_module}::#{model_id.camelize}".constantize
          register model_id, model_class, repo_id, config
        end
      end

      def load_local_entities(repo_id)
        entities_path = "./#{root}/#{repo_id}/entity"
        Dir["#{entities_path}/*.rb"].each do |file|
          entity_id = file.split('/').last.split('.').first
          require "#{entities_path}/#{entity_id}"
        end
      end

      def load_local_helpers(repo_id)
        helpers_path = "./#{root}/#{repo_id}/helpers"
        Dir["#{helpers_path}/*.rb"].each do |file|
          helper_id = file.split('/').last.split('.').first
          require "#{helpers_path}/#{helper_id}"
        end
      end
    end

  end
end
