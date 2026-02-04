# frozen_string_literal: true

require_relative 'lib/yard-is-sequel/info'

Gem::Specification::new do |spec|
  spec.name     =   IS::YARD::Sequel::Info::NAME
  spec.version  =   IS::YARD::Sequel::Info::VERSION
  spec.summary  =   IS::YARD::Sequel::Info::SUMMARY
  spec.authors  = [ IS::YARD::Sequel::Info::AUTHOR ]
  spec.license  =   IS::YARD::Sequel::Info::LICENSE
  spec.homepage =   IS::YARD::Sequel::Info::HOMEPAGE

  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]

  spec.required_ruby_version = '>= 3.4'

  spec.add_dependency 'yard', '~> 0.9'
  spec.add_dependency 'sequel', '~> 5.100'

  spec.add_development_dependency 'redcarpet'
end
