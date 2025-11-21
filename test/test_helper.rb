# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

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
