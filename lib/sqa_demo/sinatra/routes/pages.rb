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
            begin
              data = load_stock(params[:ticker])
              @stock = data[:stock]
              @ticker = data[:ticker]
              @company_name = data[:company_name]
              @show_period_selector = true
              erb :dashboard
            rescue => e
              @error = "Failed to load data for #{params[:ticker].upcase}: #{e.message}"
              erb :error
            end
          end

          # Analysis page
          app.get '/analyze/:ticker' do
            begin
              data = load_stock(params[:ticker])
              @stock = data[:stock]
              @ticker = data[:ticker]
              @company_name = data[:company_name]
              erb :analyze
            rescue => e
              @error = "Failed to load data for #{params[:ticker].upcase}: #{e.message}"
              erb :error
            end
          end

          # Backtest page
          app.get '/backtest/:ticker' do
            begin
              data = load_stock(params[:ticker])
              @stock = data[:stock]
              @ticker = data[:ticker]
              @company_name = data[:company_name]
              erb :backtest
            rescue => e
              @error = "Failed to load data for #{params[:ticker].upcase}: #{e.message}"
              erb :error
            end
          end

          # Portfolio optimizer
          app.get '/portfolio' do
            erb :portfolio
          end

          # Stock comparison page (compare multiple tickers)
          app.get '/compare' do
            tickers_param = params[:tickers] || ''
            @tickers = tickers_param.split(/\s+/).map(&:upcase).uniq.first(5)

            if @tickers.empty?
              @error = "No tickers provided. Enter up to 5 tickers separated by spaces."
              return erb :error
            end

            if tickers_param.split(/\s+/).map(&:upcase).uniq.length > 5
              @error = "Maximum of 5 tickers allowed for comparison. Please reduce your selection."
              return erb :error
            end

            @stocks_data = {}
            @errors = {}

            # Fetch data for each ticker in parallel using threads
            threads = @tickers.map do |ticker|
              Thread.new(ticker) do |t|
                fetch_comparison_data(t)
              end
            end

            # Wait for all threads to complete
            threads.each do |thread|
              ticker, data = thread.value
              if data[:error]
                @errors[ticker] = data[:error]
              else
                @stocks_data[ticker] = data
              end
            end

            erb :compare
          end

          # Company details page
          app.get '/company/:ticker' do
            begin
              data = load_stock_with_overview(params[:ticker])
              @stock = data[:stock]
              @ticker = data[:ticker]
              @company_name = data[:company_name]
              @overview = data[:overview]
              @exchange = data[:exchange]

              ohlcv = extract_ohlcv(@stock)
              prices = ohlcv[:closes]
              volumes = ohlcv[:volumes]
              dates = ohlcv[:dates]

              @data_start_date = dates.first
              @data_end_date = dates.last
              @total_trading_days = dates.length
              @current_price = prices.last
              @all_time_high = prices.max
              @all_time_low = prices.min
              @avg_volume = (volumes.sum.to_f / volumes.length).round
              @max_volume = volumes.max
              @price_range = @all_time_high - @all_time_low
              @ytd_return = calculate_ytd_return(dates, prices)

              erb :company
            rescue => e
              @error = "Failed to load data for #{params[:ticker].upcase}: #{e.message}"
              erb :error
            end
          end
        end
      end
    end
  end
end
