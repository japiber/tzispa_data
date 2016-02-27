# -*- encoding: utf-8 -*-
require File.expand_path('../lib/tzispa/data/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = Tzispa::Data::GEM_NAME
  s.version     = Tzispa::Data::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Juan Antonio Piñero']
  s.email       = ['japinero@area-integral.com']
  s.homepage    = 'https://www.area-integral.com'
  s.summary     = 'Data access for Tzispa framework'
  s.description = 'Data access layer for Tzispa'
  s.licenses    = ['MIT']

  s.required_ruby_version     =    '~> 2.3'

  s.add_dependency 'sequel',       '~> 4.31'
  s.add_dependency 'tzispa_utils', '~> 0.1'

  s.files         = Dir.glob("{lib}/**/*") + %w(README.md CHANGELOG.md)
  s.require_paths = ['lib']
end
