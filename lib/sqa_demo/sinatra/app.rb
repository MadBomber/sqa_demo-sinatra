# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'sqa'

# Load helpers
require_relative 'helpers/formatting'
require_relative 'helpers/filters'
require_relative 'helpers/stock_loader'
require_relative 'helpers/api_helpers'

# Load routes
require_relative 'routes/pages'
require_relative 'routes/api'

module SqaDemo
  module Sinatra
    class App < ::Sinatra::Base
      # Configure Sinatra
      set :root, File.dirname(__FILE__)
      set :views, File.join(root, 'views')
      set :public_folder, File.join(root, 'public')

      # Enable sessions for flash messages
      enable :sessions

      configure :development do
        require 'sinatra/reloader'
        register ::Sinatra::Reloader
        also_reload File.join(root, '**', '*.rb')
      end

      configure do
        SQA.init
      end

      # Register helpers
      helpers Helpers::Formatting
      helpers Helpers::Filters
      helpers Helpers::StockLoader
      helpers Helpers::ApiHelpers

      # Register routes
      register Routes::Pages
      register Routes::Api
    end
  end
end
