# frozen_string_literal: true

require 'date'

module SqaDemo
  module Sinatra
    module Routes
      module Pages
        def self.registered(app)
          # Home / Dashboard
          app.get '/' do
            erb :index
          end

          # Dashboard for specific ticker
          app.get '/dashboard/:ticker' do
            dashboard_page_response(params[:ticker])
          end

          # Analysis page
          app.get '/analyze/:ticker' do
            analyze_page_response(params[:ticker])
          end

          # Backtest page
          app.get '/backtest/:ticker' do
            backtest_page_response(params[:ticker])
          end

          # Portfolio optimizer
          app.get '/portfolio' do
            erb :portfolio
          end

          # Stock comparison page (compare multiple tickers)
          app.get '/compare' do
            compare_page_response(params[:tickers])
          end

          # Company details page
          app.get '/company/:ticker' do
            company_page_response(params[:ticker])
          end
        end
      end
    end
  end
end
