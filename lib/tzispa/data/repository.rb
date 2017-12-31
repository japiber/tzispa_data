# frozen_string_literal: true

require 'forwardable'
require 'sequel'
require 'tzispa_utils'
require 'tzispa/data/adapter_pool'
require 'tzispa/data/config'

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
      extend Forwardable
      include Singleton
      using Tzispa::Utils::TzString

      attr_reader :adapters, :pool, :config
      def_delegators :@adapters, :disconnect

      def initialize
        @config = Config.new(Tzispa::Environment.environment)&.to_h
        @pool = {}
        @adapters = AdapterPool.new config
      end

      class << self
        def [](model, repo_id = nil)
          repo = active_repo(repo_id)
          raise UnknownModel.new(model, repo) unless known?(model, repo)
          instance.pool[repo][model.to_sym]
        end

        def disconnect
          instance.disconnect
        end

        def active_repo(repo_id = nil)
          repo_id || instance.adapters.default_repo
        end

        def known?(model, repo)
          instance.pool.key?(repo) && instance.pool[repo].key?(model.to_sym)
        end

        def models(repo_id = nil)
          instance.pool[active_repo(repo_id)].values
        end

        def module_const(repo_id = nil)
          repo = active_repo(repo_id)
          instance.pool[repo][:__repository_module] ||= instance.repository_module(repo)
        end

        def load!(domain)
          instance.config.each do |id, cfg|
            instance.pool[id] = {}
            instance.load_config_repo(id, cfg)
            domain.include module_const(id)
          end
        end

        def register(model_id, model_class, repo_id, config)
          return if known?(model_id, repo_id)
          instance.setup_model(model_class, repo_id, config)
          instance.pool[repo_id][model_id.to_sym] = model_class
        end
      end

      def setup_model(model_class, repo_id, config)
        return if model_class.db == adapters[repo_id]
        model_class.db = adapters[repo_id]
        return unless config.caching
        model_class.plugin :caching, adapters.cache[repo_id],
                           ttl: config.ttl || DEFAULT_CACHE_TTL,
                           ignore_exceptions: true
      end

      def repository_module(repo_id)
        rm = @pool[repo_id].first[1].name.split('::')
        rm.pop
        rm.join('::').constantize
      end

      def load_config_repo(id, cfg)
        if cfg.local
          local_local(id, cfg)
        else
          require cfg.gem
          repo_module = id.to_s.camelize.constantize
          self.class.include repo_module
          self.class.send "load_#{id}", id, cfg
        end
      end

      private

      def root(cfg)
        cfg.root || LOCAL_REPO_ROOT
      end

      def local_local(id, cfg)
        local_root = root(cfg)
        load_local_helpers id, local_root
        load_local_models id, cfg, local_root
        load_local_entities id, local_root
      end

      def load_local_models(repo_id, cfg, root)
        models_path = "./#{root}/#{repo_id}/model"
        repo_module = "#{repo_id.to_s.camelize}::Model".constantize
        Dir["#{models_path}/*.rb"].each do |file|
          model_id = file.split('/').last.split('.').first
          require "#{models_path}/#{model_id}"
          model_class = "#{repo_module}::#{model_id.camelize}".constantize
          register model_id, model_class, repo_id, cfg
        end
      end

      def load_local_entities(repo_id, root)
        entities_path = "./#{root}/#{repo_id}/entity"
        Dir["#{entities_path}/*.rb"].each do |file|
          entity_id = file.split('/').last.split('.').first
          require "#{entities_path}/#{entity_id}"
        end
      end

      def load_local_helpers(repo_id, root)
        helpers_path = "./#{root}/#{repo_id}/helpers"
        Dir["#{helpers_path}/*.rb"].each do |file|
          helper_id = file.split('/').last.split('.').first
          require "#{helpers_path}/#{helper_id}"
        end
      end

      LOCAL_REPO_ROOT = :repository

      DEFAULT_CACHE_TTL = 900
    end

  end
end
