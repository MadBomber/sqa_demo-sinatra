# frozen_string_literal: true

require_relative 'lib/sqa_demo/sinatra/version'

Gem::Specification.new do |spec|
  spec.name          = 'sqa_demo-sinatra'
  spec.version       = SqaDemo::Sinatra::VERSION
  spec.authors       = ['Dewayne VanHoozer']
  spec.email         = ['dvanhoozer@gmail.com']

  spec.summary       = 'SQA Demo Sinatra Application'
  spec.description   = 'A Sinatra-based web application for stock market analysis using the SQA library'
  spec.homepage      = 'https://github.com/madbomber/sqa_demo-sinatra'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'bin'
  spec.executables = ['sqa_sinatra']
  spec.require_paths = ['lib']

  # Web framework
  spec.add_dependency 'puma', '~> 6.0'
  spec.add_dependency 'rackup'
  spec.add_dependency 'sinatra', '~> 4.0'
  spec.add_dependency 'sinatra-contrib', '~> 4.0'

  # JSON handling
  spec.add_dependency 'json', '~> 2.7'

  # SQA library
  spec.add_dependency 'sqa'

  # Development dependencies
  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rerun'
end
