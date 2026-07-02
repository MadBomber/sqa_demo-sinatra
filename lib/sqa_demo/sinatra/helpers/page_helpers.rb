# frozen_string_literal: true

module SqaDemo
  module Sinatra
    module Helpers
      module PageHelpers
        # GET /dashboard/:ticker
        def dashboard_page_response(ticker_param)
          assign_stock_ivars(load_stock(ticker_param))
          @show_period_selector = true
          erb :dashboard
        rescue => e
          assign_load_error(ticker_param, e)
          erb :error
        end

        # GET /analyze/:ticker
        def analyze_page_response(ticker_param)
          assign_stock_ivars(load_stock(ticker_param))
          erb :analyze
        rescue => e
          assign_load_error(ticker_param, e)
          erb :error
        end

        # GET /backtest/:ticker
        def backtest_page_response(ticker_param)
          assign_stock_ivars(load_stock(ticker_param))
          erb :backtest
        rescue => e
          assign_load_error(ticker_param, e)
          erb :error
        end

        # GET /compare - stock comparison page (compare multiple tickers)
        def compare_page_response(tickers_param)
          @tickers = parse_compare_tickers(tickers_param)

          if @tickers.empty?
            @error = "No tickers provided. Enter up to 5 tickers separated by spaces."
            return erb :error
          end

          if too_many_compare_tickers?(tickers_param)
            @error = "Maximum of 5 tickers allowed for comparison. Please reduce your selection."
            return erb :error
          end

          @stocks_data, @errors = fetch_comparison_data_for(@tickers)

          erb :compare
        end

        # GET /company/:ticker
        def company_page_response(ticker_param)
          data = load_stock_with_overview(ticker_param)
          assign_stock_ivars(data)
          @overview = data[:overview]
          @exchange = data[:exchange]

          assign_company_stats(extract_ohlcv(@stock))

          erb :company
        rescue => e
          assign_load_error(ticker_param, e)
          erb :error
        end

        private

        # Assign the common @stock/@ticker/@company_name ivars used by page templates
        def assign_stock_ivars(data)
          @stock = data[:stock]
          @ticker = data[:ticker]
          @company_name = data[:company_name]
        end

        # Assign the common @error ivar used by the error template
        def assign_load_error(ticker_param, error)
          @error = "Failed to load data for #{ticker_param.upcase}: #{error.message}"
        end

        # Parse and normalize the raw tickers query param into a deduped, capped list
        def parse_compare_tickers(tickers_param)
          (tickers_param || '').split(/\s+/).map(&:upcase).uniq.first(5)
        end

        # True when the caller supplied more than 5 distinct tickers
        def too_many_compare_tickers?(tickers_param)
          (tickers_param || '').split(/\s+/).map(&:upcase).uniq.length > 5
        end

        # Fetch comparison data for each ticker in parallel, splitting successes from errors
        def fetch_comparison_data_for(tickers)
          threads = tickers.map do |ticker|
            Thread.new(ticker) do |t|
              fetch_comparison_data(t)
            end
          end

          stocks_data = {}
          errors = {}

          threads.each do |thread|
            ticker, data = thread.value
            if data[:error]
              errors[ticker] = data[:error]
            else
              stocks_data[ticker] = data
            end
          end

          [stocks_data, errors]
        end

        # Assign the @data_start_date..@ytd_return ivars used by the company template
        def assign_company_stats(ohlcv)
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
        end
      end
    end
  end
end
