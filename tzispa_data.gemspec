# frozen_string_literal: true

require File.expand_path('../lib/tzispa/data/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = Tzispa::Data::GEM_NAME
  s.version     = Tzispa::Data::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Juan Antonio Piñero']
  s.email       = ['japinero@area-integral.com']
  s.homepage    = 'https://github.com/japiber/tzispa_data'
  s.summary     = 'Data access for Tzispa framework'
  s.description = 'Data access layer for Tzispa'
  s.licenses    = ['MIT']

  s.required_ruby_version = '~> 2.4'

  s.add_dependency 'dalli',          '~> 2.7'
  s.add_dependency 'sequel',         '~> 5.2'
  s.add_dependency 'tzispa_config',  '~> 0.1.0'
  s.add_dependency 'tzispa_utils',   '~> 0.3.5'

  s.files         = Dir.glob("{lib}/**/*") + %w(README.md CHANGELOG.md)
  s.require_paths = ['lib']
end
