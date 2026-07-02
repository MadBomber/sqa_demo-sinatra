# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_group 'Routes', 'lib/sqa_demo/sinatra/routes'
  add_group 'Helpers', 'lib/sqa_demo/sinatra/helpers'
end

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'

require_relative '../lib/sqa_demo/sinatra'

module TestHelper
  include Rack::Test::Methods

  def app
    SqaDemo::Sinatra::App
  end
end
