# frozen_string_literal: true

require 'date'

module SqaDemo
  module Sinatra
    module Routes
      module Api
        def self.registered(app)
          # Get stock data
          app.get '/api/stock/:ticker' do
            content_type :json
            api_stock_response(params[:ticker], params[:period])
          end

          # Get technical indicators
          app.get '/api/indicators/:ticker' do
            content_type :json
            api_indicators_response(params[:ticker], params[:period])
          end

          # Run backtest
          app.post '/api/backtest/:ticker' do
            content_type :json
            api_backtest_response(params[:ticker], params[:strategy])
          end

          # Run market analysis
          app.get '/api/analyze/:ticker' do
            content_type :json
            api_analyze_response(params[:ticker])
          end

          # Compare strategies
          app.post '/api/compare/:ticker' do
            content_type :json
            api_compare_response(params[:ticker])
          end
        end
      end
    end
  end
end
