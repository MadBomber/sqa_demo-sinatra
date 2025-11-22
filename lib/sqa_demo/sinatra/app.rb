# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'sqa'

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

      # Helpers
      helpers do
        def format_percent(value)
          sprintf("%.2f%%", value)
        end

        def format_currency(value)
          sprintf("$%.2f", value)
        end

        def format_number(value)
          value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        end

        # Format comparison value based on type
        def format_compare_value(value, format_type)
          return 'N/A' if value.nil?
          case format_type
          when :currency
            sprintf('$%.2f', value)
          when :currency_billions
            sprintf('$%.2fB', value / 1_000_000_000.0)
          when :percent
            sprintf('%.2f%%', value)
          when :percent_sign
            prefix = value >= 0 ? '+' : ''
            "#{prefix}#{sprintf('%.2f', value)}%"
          when :percent_from_decimal
            sprintf('%.1f%%', value * 100)
          when :decimal2
            sprintf('%.2f', value)
          when :decimal3
            sprintf('%.3f', value)
          when :number
            value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          else
            value.to_s
          end
        end

        # Find best/worst tickers for a given metric
        def find_extremes(stocks_data, key, higher_is_better)
          return [nil, nil] if higher_is_better.nil?
          values = stocks_data.map { |t, d| [t, d[key]] }.reject { |_, v| v.nil? }
          return [nil, nil] if values.empty?

          sorted = values.sort_by { |_, v| v }
          if higher_is_better
            [sorted.last[0], sorted.first[0]]  # best is highest, worst is lowest
          else
            [sorted.first[0], sorted.last[0]]  # best is lowest, worst is highest
          end
        end

        # Filter data arrays by time period
        # period can be: "30d", "60d", "90d", "1q", "2q", "3q", "4q", "all"
        def filter_by_period(dates, *data_arrays, period: 'all')
          return [dates, *data_arrays] if period == 'all' || dates.empty?

          require 'date'

          # Parse dates (they're strings in YYYY-MM-DD format)
          parsed_dates = dates.map { |d| Date.parse(d) }
          latest_date = parsed_dates.max

          # Calculate cutoff date based on period
          cutoff_date = case period
                        when '30d'
                          latest_date - 30
                        when '60d'
                          latest_date - 60
                        when '90d'
                          latest_date - 90
                        when '1q'
                          latest_date - 63  # ~3 months = 1 quarter (63 trading days)
                        when '2q'
                          latest_date - 126 # ~6 months = 2 quarters
                        when '3q'
                          latest_date - 189 # ~9 months = 3 quarters
                        when '4q'
                          latest_date - 252 # ~12 months = 4 quarters
                        else
                          parsed_dates.min # "all" - keep everything
                        end

          # Find indices where date >= cutoff_date
          indices = parsed_dates.each_with_index.select { |d, _i| d >= cutoff_date }.map(&:last)

          # Filter all arrays by the same indices
          filtered_dates = indices.map { |i| dates[i] }
          filtered_data = data_arrays.map { |arr| indices.map { |i| arr[i] } }

          [filtered_dates, *filtered_data]
        end
      end

      # Routes

      # Home / Dashboard
      get '/' do
        erb :index
      end

      # Dashboard for specific ticker
      get '/dashboard/:ticker' do
        ticker = params[:ticker].upcase

        begin
          @stock = SQA::Stock.new(ticker: ticker)
          @ticker = ticker
          @show_period_selector = true
          ticker_info = SQA::Ticker.lookup(ticker)
          @company_name = ticker_info[:name] if ticker_info
          erb :dashboard
        rescue => e
          @error = "Failed to load data for #{ticker}: #{e.message}"
          erb :error
        end
      end

      # Analysis page
      get '/analyze/:ticker' do
        ticker = params[:ticker].upcase

        begin
          @stock = SQA::Stock.new(ticker: ticker)
          @ticker = ticker
          ticker_info = SQA::Ticker.lookup(ticker)
          @company_name = ticker_info[:name] if ticker_info
          erb :analyze
        rescue => e
          @error = "Failed to load data for #{ticker}: #{e.message}"
          erb :error
        end
      end

      # Backtest page
      get '/backtest/:ticker' do
        ticker = params[:ticker].upcase

        begin
          @stock = SQA::Stock.new(ticker: ticker)
          @ticker = ticker
          ticker_info = SQA::Ticker.lookup(ticker)
          @company_name = ticker_info[:name] if ticker_info
          erb :backtest
        rescue => e
          @error = "Failed to load data for #{ticker}: #{e.message}"
          erb :error
        end
      end

      # Portfolio optimizer
      get '/portfolio' do
        erb :portfolio
      end

      # Stock comparison page (compare multiple tickers)
      get '/compare' do
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
            begin
              stock = SQA::Stock.new(ticker: t)
              df = stock.df
              prices = df["adj_close_price"].to_a
              volumes = df["volume"].to_a
              dates = df["timestamp"].to_a.map(&:to_s)
              highs = df["high_price"].to_a
              lows = df["low_price"].to_a

              # Get company overview
              raw_overview = stock.overview || {}
              overview = raw_overview.transform_keys(&:to_sym)

              # Fallback to ticker lookup
              if overview.empty?
                ticker_info = SQA::Ticker.lookup(t)
                company_name = ticker_info[:name]&.strip if ticker_info
              else
                company_name = overview[:name]&.strip
              end

              # Calculate basic metrics
              current_price = prices.last
              prev_price = prices[-2] || prices.last
              change = current_price - prev_price
              change_pct = prev_price > 0 ? (change / prev_price * 100) : 0

              # Calculate technical indicators
              rsi = SQAI.rsi(prices, period: 14).last rescue nil
              macd_result = SQAI.macd(prices) rescue [[], [], []]
              macd_line = macd_result[0].last rescue nil
              macd_signal = macd_result[1].last rescue nil
              macd_hist = macd_result[2].last rescue nil

              stoch_result = SQAI.stoch(highs, lows, prices) rescue [[], []]
              stoch_k = stoch_result[0].last rescue nil
              stoch_d = stoch_result[1].last rescue nil

              sma_50 = SQAI.sma(prices, period: 50).last rescue nil
              sma_200 = SQAI.sma(prices, period: 200).last rescue nil
              ema_20 = SQAI.ema(prices, period: 20).last rescue nil

              bb_result = SQAI.bbands(prices) rescue [[], [], []]
              bb_upper = bb_result[0].last rescue nil
              bb_middle = bb_result[1].last rescue nil
              bb_lower = bb_result[2].last rescue nil

              adx = SQAI.adx(highs, lows, prices, period: 14).last rescue nil
              atr = SQAI.atr(highs, lows, prices, period: 14).last rescue nil
              cci = SQAI.cci(highs, lows, prices, period: 14).last rescue nil
              willr = SQAI.willr(highs, lows, prices, period: 14).last rescue nil
              mom = SQAI.mom(prices, period: 10).last rescue nil
              roc = SQAI.roc(prices, period: 10).last rescue nil

              # Calculate 52-week high/low
              high_52w = prices.last(252).max rescue prices.max
              low_52w = prices.last(252).min rescue prices.min

              # Calculate YTD return
              require 'date'
              current_year = Date.today.year
              ytd_prices = dates.each_with_index.select { |d, _| Date.parse(d).year == current_year }.map { |_, i| prices[i] }
              ytd_return = if ytd_prices.length > 1
                ((ytd_prices.last - ytd_prices.first) / ytd_prices.first * 100).round(2)
              else
                nil
              end

              # Risk metrics
              returns = prices.each_cons(2).map { |a, b| (b - a) / a }
              sharpe = SQA::RiskManager.sharpe_ratio(returns) rescue nil
              max_dd = SQA::RiskManager.max_drawdown(prices) rescue nil
              max_drawdown = max_dd ? max_dd[:max_drawdown] : nil

              # Average volume
              avg_volume = (volumes.sum.to_f / volumes.length).round rescue nil

              [t, {
                ticker: t,
                company_name: company_name,
                current_price: current_price,
                change: change,
                change_pct: change_pct,
                high_52w: high_52w,
                low_52w: low_52w,
                ytd_return: ytd_return,
                avg_volume: avg_volume,
                # Technical indicators
                rsi: rsi,
                macd: macd_line,
                macd_signal: macd_signal,
                macd_hist: macd_hist,
                stoch_k: stoch_k,
                stoch_d: stoch_d,
                sma_50: sma_50,
                sma_200: sma_200,
                ema_20: ema_20,
                bb_upper: bb_upper,
                bb_middle: bb_middle,
                bb_lower: bb_lower,
                adx: adx,
                atr: atr,
                cci: cci,
                willr: willr,
                mom: mom,
                roc: roc,
                # Fundamental data from overview
                pe_ratio: overview[:pe_ratio],
                forward_pe: overview[:forward_pe],
                peg_ratio: overview[:peg_ratio],
                price_to_book: overview[:price_to_book_ratio],
                eps: overview[:eps],
                dividend_yield: overview[:dividend_yield],
                profit_margin: overview[:profit_margin],
                operating_margin: overview[:operating_margin_ttm],
                roe: overview[:return_on_equity_ttm],
                roa: overview[:return_on_assets_ttm],
                market_cap: overview[:market_capitalization],
                beta: overview[:beta],
                analyst_target: overview[:analyst_target_price],
                # Risk metrics
                sharpe_ratio: sharpe,
                max_drawdown: max_drawdown
              }]
            rescue => e
              [t, { error: e.message }]
            end
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
      get '/company/:ticker' do
        ticker = params[:ticker].upcase

        begin
          @stock = SQA::Stock.new(ticker: ticker)
          @ticker = ticker

          # Get comprehensive company overview from SQA (convert string keys to symbols)
          raw_overview = @stock.overview || {}
          @overview = raw_overview.transform_keys(&:to_sym)

          # Fallback to ticker lookup if overview is empty
          if @overview.empty?
            ticker_info = SQA::Ticker.lookup(ticker)
            @company_name = ticker_info[:name] if ticker_info
            @exchange = ticker_info[:exchange] if ticker_info
          else
            @company_name = @overview[:name]
            @exchange = @overview[:exchange]
          end

          df = @stock.df
          prices = df["adj_close_price"].to_a
          volumes = df["volume"].to_a
          dates = df["timestamp"].to_a.map(&:to_s)

          @data_start_date = dates.first
          @data_end_date = dates.last
          @total_trading_days = dates.length
          @current_price = prices.last
          @all_time_high = prices.max
          @all_time_low = prices.min
          @avg_volume = (volumes.sum.to_f / volumes.length).round
          @max_volume = volumes.max
          @price_range = @all_time_high - @all_time_low

          # Calculate year-to-date return if available
          require 'date'
          current_year = Date.today.year
          ytd_prices = dates.each_with_index.select { |d, _| Date.parse(d).year == current_year }.map { |_, i| prices[i] }
          if ytd_prices.length > 1
            @ytd_return = ((ytd_prices.last - ytd_prices.first) / ytd_prices.first * 100).round(2)
          end

          erb :company
        rescue => e
          @error = "Failed to load data for #{ticker}: #{e.message}"
          erb :error
        end
      end

      # API Endpoints

      # Get stock data
      get '/api/stock/:ticker' do
        content_type :json

        ticker = params[:ticker].upcase
        period = params[:period] || 'all'

        begin
          stock = SQA::Stock.new(ticker: ticker)
          df = stock.df

          # Get price data (all data first)
          dates = df["timestamp"].to_a.map(&:to_s)
          opens = df["open_price"].to_a
          highs = df["high_price"].to_a
          lows = df["low_price"].to_a
          closes = df["adj_close_price"].to_a
          volumes = df["volume"].to_a

          # Filter by period
          filtered_dates, filtered_opens, filtered_highs, filtered_lows, filtered_closes, filtered_volumes =
            filter_by_period(dates, opens, highs, lows, closes, volumes, period: period)

          # Calculate basic stats
          current_price = filtered_closes.last
          prev_price = filtered_closes[-2]
          change = current_price - prev_price
          change_pct = (change / prev_price) * 100

          # 52-week high/low uses full data for reference
          high_52w = closes.last(252).max rescue closes.max
          low_52w = closes.last(252).min rescue closes.min

          {
            ticker: ticker,
            period: period,
            current_price: current_price,
            change: change,
            change_percent: change_pct,
            high_52w: high_52w,
            low_52w: low_52w,
            dates: filtered_dates,
            open: filtered_opens,
            high: filtered_highs,
            low: filtered_lows,
            close: filtered_closes,
            volume: filtered_volumes
          }.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Get technical indicators
      get '/api/indicators/:ticker' do
        content_type :json

        ticker = params[:ticker].upcase
        period = params[:period] || 'all'

        begin
          stock = SQA::Stock.new(ticker: ticker)
          df = stock.df

          prices = df["adj_close_price"].to_a
          opens = df["open_price"].to_a
          highs = df["high_price"].to_a
          lows = df["low_price"].to_a
          volumes = df["volume"].to_a
          dates = df["timestamp"].to_a.map(&:to_s)
          n = prices.length

          # Calculate price indicators on full dataset (they need historical context)
          rsi = SQAI.rsi(prices, period: 14)
          macd_result = SQAI.macd(prices)
          bb_result = SQAI.bbands(prices)
          sma_12 = SQAI.sma(prices, period: 12)
          sma_20 = SQAI.sma(prices, period: 20)
          sma_50 = SQAI.sma(prices, period: 50)
          ema_20 = SQAI.ema(prices, period: 20)

          # Additional moving averages for price overlay
          wma_20 = SQAI.wma(prices, period: 20)
          dema_20 = SQAI.dema(prices, period: 20)
          tema_20 = SQAI.tema(prices, period: 20)
          kama_30 = SQAI.kama(prices, period: 30)

          # Momentum indicators (require high/low/close)
          stoch_result = SQAI.stoch(highs, lows, prices)
          mom_10 = SQAI.mom(prices, period: 10)
          cci_14 = SQAI.cci(highs, lows, prices, period: 14)
          willr_14 = SQAI.willr(highs, lows, prices, period: 14)
          roc_10 = SQAI.roc(prices, period: 10)
          adx_14 = SQAI.adx(highs, lows, prices, period: 14)

          # Volatility indicators
          atr_14 = SQAI.atr(highs, lows, prices, period: 14)

          # Volume indicators
          obv = SQAI.obv(prices, volumes)
          ad = SQAI.ad(highs, lows, prices, volumes)

          # Calculate volume moving averages
          vol_sma_12 = SQAI.sma(volumes, period: 12)
          vol_sma_20 = SQAI.sma(volumes, period: 20)
          vol_sma_50 = SQAI.sma(volumes, period: 50)
          vol_ema_12 = SQAI.ema(volumes, period: 12)
          vol_ema_20 = SQAI.ema(volumes, period: 20)

          # Candlestick pattern recognition (high-priority patterns)
          cdl_doji = SQAI.cdl_doji(opens, highs, lows, prices)
          cdl_hammer = SQAI.cdl_hammer(opens, highs, lows, prices)
          cdl_shootingstar = SQAI.cdl_shootingstar(opens, highs, lows, prices)
          cdl_engulfing = SQAI.cdl_engulfing(opens, highs, lows, prices)
          cdl_morningstar = SQAI.cdl_morningstar(opens, highs, lows, prices)
          cdl_eveningstar = SQAI.cdl_eveningstar(opens, highs, lows, prices)
          cdl_harami = SQAI.cdl_harami(opens, highs, lows, prices)
          cdl_3whitesoldiers = SQAI.cdl_3whitesoldiers(opens, highs, lows, prices)
          cdl_3blackcrows = SQAI.cdl_3blackcrows(opens, highs, lows, prices)
          cdl_piercing = SQAI.cdl_piercing(opens, highs, lows, prices)
          cdl_darkcloudcover = SQAI.cdl_darkcloudcover(opens, highs, lows, prices)
          cdl_marubozu = SQAI.cdl_marubozu(opens, highs, lows, prices)

          # Pad indicator arrays with nil at the beginning to align with dates
          # Indicators return shorter arrays due to warmup periods
          pad_array = ->(arr) { Array.new(n - arr.length, nil) + arr }

          rsi = pad_array.call(rsi)
          macd_line = pad_array.call(macd_result[0])
          macd_signal = pad_array.call(macd_result[1])
          macd_hist = pad_array.call(macd_result[2])
          bb_upper = pad_array.call(bb_result[0])
          bb_middle = pad_array.call(bb_result[1])
          bb_lower = pad_array.call(bb_result[2])
          sma_12 = pad_array.call(sma_12)
          sma_20 = pad_array.call(sma_20)
          sma_50 = pad_array.call(sma_50)
          ema_20 = pad_array.call(ema_20)

          # Pad additional moving averages
          wma_20 = pad_array.call(wma_20)
          dema_20 = pad_array.call(dema_20)
          tema_20 = pad_array.call(tema_20)
          kama_30 = pad_array.call(kama_30)

          # Pad momentum indicators
          stoch_slowk = pad_array.call(stoch_result[0])
          stoch_slowd = pad_array.call(stoch_result[1])
          mom_10 = pad_array.call(mom_10)
          cci_14 = pad_array.call(cci_14)
          willr_14 = pad_array.call(willr_14)
          roc_10 = pad_array.call(roc_10)
          adx_14 = pad_array.call(adx_14)

          # Pad volatility indicators
          atr_14 = pad_array.call(atr_14)

          # Pad volume indicators
          obv = pad_array.call(obv)
          ad = pad_array.call(ad)
          vol_sma_12 = pad_array.call(vol_sma_12)
          vol_sma_20 = pad_array.call(vol_sma_20)
          vol_sma_50 = pad_array.call(vol_sma_50)
          vol_ema_12 = pad_array.call(vol_ema_12)
          vol_ema_20 = pad_array.call(vol_ema_20)

          # Pad pattern arrays
          cdl_doji = pad_array.call(cdl_doji)
          cdl_hammer = pad_array.call(cdl_hammer)
          cdl_shootingstar = pad_array.call(cdl_shootingstar)
          cdl_engulfing = pad_array.call(cdl_engulfing)
          cdl_morningstar = pad_array.call(cdl_morningstar)
          cdl_eveningstar = pad_array.call(cdl_eveningstar)
          cdl_harami = pad_array.call(cdl_harami)
          cdl_3whitesoldiers = pad_array.call(cdl_3whitesoldiers)
          cdl_3blackcrows = pad_array.call(cdl_3blackcrows)
          cdl_piercing = pad_array.call(cdl_piercing)
          cdl_darkcloudcover = pad_array.call(cdl_darkcloudcover)
          cdl_marubozu = pad_array.call(cdl_marubozu)

          # Detect patterns from the data
          # Pattern types:
          #   :neutral - always neutral signal (Doji)
          #   :fixed - predetermined signal regardless of value sign
          #   :directional - sign of value determines bullish (+) or bearish (-)
          pattern_defs = {
            doji: { data: cdl_doji, name: 'Doji', type: :neutral },
            hammer: { data: cdl_hammer, name: 'Hammer', type: :fixed, signal: 'bullish' },
            shootingstar: { data: cdl_shootingstar, name: 'Shooting Star', type: :fixed, signal: 'bearish' },
            engulfing: { data: cdl_engulfing, name: 'Engulfing', type: :directional },
            morningstar: { data: cdl_morningstar, name: 'Morning Star', type: :fixed, signal: 'bullish' },
            eveningstar: { data: cdl_eveningstar, name: 'Evening Star', type: :fixed, signal: 'bearish' },
            harami: { data: cdl_harami, name: 'Harami', type: :directional },
            whitesoldiers: { data: cdl_3whitesoldiers, name: 'Three White Soldiers', type: :fixed, signal: 'bullish' },
            blackcrows: { data: cdl_3blackcrows, name: 'Three Black Crows', type: :fixed, signal: 'bearish' },
            piercing: { data: cdl_piercing, name: 'Piercing', type: :fixed, signal: 'bullish' },
            darkcloudcover: { data: cdl_darkcloudcover, name: 'Dark Cloud Cover', type: :fixed, signal: 'bearish' },
            marubozu: { data: cdl_marubozu, name: 'Marubozu', type: :directional }
          }

          detected_patterns = []
          pattern_defs.each do |_key, pdef|
            pdef[:data].each_with_index do |val, i|
              next if val.nil? || val == 0

              signal = case pdef[:type]
                       when :neutral then 'neutral'
                       when :fixed then pdef[:signal]
                       when :directional then val > 0 ? 'bullish' : 'bearish'
                       end

              detected_patterns << {
                date: dates[i],
                pattern: pdef[:name],
                signal: signal,
                strength: val.abs
              }
            end
          end
          # Sort by date descending and keep only 20 most recent
          detected_patterns.sort_by! { |p| p[:date] }.reverse!
          detected_patterns = detected_patterns.first(20)

          # Filter results by period (keep indicators aligned with dates)
          filtered_dates, filtered_rsi, filtered_macd, filtered_macd_signal, filtered_macd_hist,
            filtered_bb_upper, filtered_bb_middle, filtered_bb_lower,
            filtered_sma_12, filtered_sma_20, filtered_sma_50, filtered_ema_20,
            filtered_wma_20, filtered_dema_20, filtered_tema_20, filtered_kama_30,
            filtered_stoch_slowk, filtered_stoch_slowd, filtered_mom_10,
            filtered_cci_14, filtered_willr_14, filtered_roc_10, filtered_adx_14,
            filtered_atr_14, filtered_obv, filtered_ad,
            filtered_vol_sma_12, filtered_vol_sma_20, filtered_vol_sma_50,
            filtered_vol_ema_12, filtered_vol_ema_20 =
            filter_by_period(dates, rsi, macd_line, macd_signal, macd_hist,
                             bb_upper, bb_middle, bb_lower,
                             sma_12, sma_20, sma_50, ema_20,
                             wma_20, dema_20, tema_20, kama_30,
                             stoch_slowk, stoch_slowd, mom_10,
                             cci_14, willr_14, roc_10, adx_14,
                             atr_14, obv, ad,
                             vol_sma_12, vol_sma_20, vol_sma_50,
                             vol_ema_12, vol_ema_20, period: period)

          {
            period: period,
            dates: filtered_dates,
            rsi: filtered_rsi,
            macd: filtered_macd,
            macd_signal: filtered_macd_signal,
            macd_hist: filtered_macd_hist,
            bb_upper: filtered_bb_upper,
            bb_middle: filtered_bb_middle,
            bb_lower: filtered_bb_lower,
            sma_12: filtered_sma_12,
            sma_20: filtered_sma_20,
            sma_50: filtered_sma_50,
            ema_20: filtered_ema_20,
            wma_20: filtered_wma_20,
            dema_20: filtered_dema_20,
            tema_20: filtered_tema_20,
            kama_30: filtered_kama_30,
            stoch_slowk: filtered_stoch_slowk,
            stoch_slowd: filtered_stoch_slowd,
            mom_10: filtered_mom_10,
            cci_14: filtered_cci_14,
            willr_14: filtered_willr_14,
            roc_10: filtered_roc_10,
            adx_14: filtered_adx_14,
            atr_14: filtered_atr_14,
            obv: filtered_obv,
            ad: filtered_ad,
            vol_sma_12: filtered_vol_sma_12,
            vol_sma_20: filtered_vol_sma_20,
            vol_sma_50: filtered_vol_sma_50,
            vol_ema_12: filtered_vol_ema_12,
            vol_ema_20: filtered_vol_ema_20,
            patterns: detected_patterns || []
          }.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Run backtest
      post '/api/backtest/:ticker' do
        content_type :json

        ticker = params[:ticker].upcase
        strategy_name = params[:strategy] || 'RSI'

        begin
          stock = SQA::Stock.new(ticker: ticker)

          # Resolve strategy
          strategy = case strategy_name.upcase
                     when 'RSI' then SQA::Strategy::RSI
                     when 'SMA' then SQA::Strategy::SMA
                     when 'EMA' then SQA::Strategy::EMA
                     when 'MACD' then SQA::Strategy::MACD
                     when 'BOLLINGERBANDS' then SQA::Strategy::BollingerBands
                     when 'KBS' then SQA::Strategy::KBS
                     else SQA::Strategy::RSI
                     end

          # Run backtest
          backtest = SQA::Backtest.new(
            stock: stock,
            strategy: strategy,
            initial_capital: 10_000.0,
            commission: 1.0
          )

          results = backtest.run

          {
            total_return: results.total_return,
            annualized_return: results.annualized_return,
            sharpe_ratio: results.sharpe_ratio,
            max_drawdown: results.max_drawdown,
            win_rate: results.win_rate,
            total_trades: results.total_trades,
            profit_factor: results.profit_factor,
            avg_win: results.avg_win,
            avg_loss: results.avg_loss
          }.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Run market analysis
      get '/api/analyze/:ticker' do
        content_type :json

        ticker = params[:ticker].upcase

        begin
          stock = SQA::Stock.new(ticker: ticker)
          prices = stock.df["adj_close_price"].to_a

          # Market regime
          regime = SQA::MarketRegime.detect(stock)

          # Seasonal analysis
          seasonal = SQA::SeasonalAnalyzer.analyze(stock)

          # FPOP analysis - shows historical (verifiable) + future predictions
          require 'date'
          dates = stock.df["timestamp"].to_a.map(&:to_s)
          last_date = Date.parse(dates.last)
          fpop_period = 10
          fpop_data = SQA::FPOP.fpl_analysis(prices, fpop: fpop_period)

          # Generate future trading dates (skip weekends) starting after last_date
          future_dates = []
          current_date = last_date + 1
          while future_dates.length < fpop_period
            unless current_date.saturday? || current_date.sunday?
              future_dates << current_date.to_s
            end
            current_date += 1
          end

          # Show last 5 historical predictions (verifiable) + 10 future predictions
          num_historical = [5, dates.length - 1].min
          recent_fpop = []

          # Historical: predictions with actual results for verification
          hist_start = dates.length - num_historical - 1
          (0...num_historical).each do |i|
            idx = hist_start + i
            target_idx = idx + 1
            next if idx < 0 || idx >= fpop_data.length || target_idx >= prices.length

            # Calculate actual price change
            prev_price = prices[idx]
            actual_price = prices[target_idx]
            actual_change = ((actual_price - prev_price) / prev_price) * 100
            actual_direction = actual_change > 0.1 ? 'UP' : (actual_change < -0.1 ? 'DOWN' : 'FLAT')

            # Determine if prediction was correct
            # Correct if absolute difference between predicted magnitude and actual change is <= 1%
            predicted_magnitude = fpop_data[idx][:magnitude]
            difference = (predicted_magnitude - actual_change).abs
            correct = difference <= 1.0

            recent_fpop << {
              date: dates[target_idx],
              direction: fpop_data[idx][:direction],
              magnitude: fpop_data[idx][:magnitude],
              risk: fpop_data[idx][:risk],
              interpretation: fpop_data[idx][:interpretation],
              actual_change: actual_change.round(2),
              actual_direction: actual_direction,
              correct: correct,
              is_future: false
            }
          end

          # Future: predictions starting from the day after last_date
          fpop_data.last(fpop_period).each_with_index do |f, i|
            recent_fpop << {
              date: future_dates[i],
              direction: f[:direction],
              magnitude: f[:magnitude],
              risk: f[:risk],
              interpretation: f[:interpretation],
              actual_change: nil,
              actual_direction: nil,
              correct: nil,
              is_future: true
            }
          end

          # Risk metrics
          returns = prices.each_cons(2).map { |a, b| (b - a) / a }
          var_95 = SQA::RiskManager.var(returns, confidence: 0.95)
          sharpe = SQA::RiskManager.sharpe_ratio(returns)
          max_dd = SQA::RiskManager.max_drawdown(prices)

          {
            regime: {
              type: regime[:type],
              volatility: regime[:volatility],
              strength: regime[:strength_score],
              trend: regime[:trend_score]
            },
            seasonal: {
              best_months: seasonal[:best_months],
              worst_months: seasonal[:worst_months],
              best_quarters: seasonal[:best_quarters],
              has_pattern: seasonal[:has_seasonal_pattern]
            },
            fpop: recent_fpop,
            risk: {
              var_95: var_95,
              sharpe_ratio: sharpe,
              max_drawdown: max_dd[:max_drawdown]
            }
          }.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end

      # Compare strategies
      post '/api/compare/:ticker' do
        content_type :json

        ticker = params[:ticker].upcase

        begin
          stock = SQA::Stock.new(ticker: ticker)

          strategies = {
            'RSI' => SQA::Strategy::RSI,
            'SMA' => SQA::Strategy::SMA,
            'EMA' => SQA::Strategy::EMA,
            'MACD' => SQA::Strategy::MACD,
            'BollingerBands' => SQA::Strategy::BollingerBands
          }

          results = strategies.map do |name, strategy_class|
            backtest = SQA::Backtest.new(
              stock: stock,
              strategy: strategy_class,
              initial_capital: 10_000.0,
              commission: 1.0
            )

            result = backtest.run

            {
              strategy: name,
              return: result.total_return,
              sharpe: result.sharpe_ratio,
              drawdown: result.max_drawdown,
              win_rate: result.win_rate,
              trades: result.total_trades
            }
          rescue => e
            nil
          end.compact

          results.sort_by! { |r| -r[:return] }
          results.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end
      end
    end
  end
end
