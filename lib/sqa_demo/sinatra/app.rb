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

          # FPOP analysis
          fpop_data = SQA::FPOP.fpl_analysis(prices, fpop: 10)
          recent_fpop = fpop_data.last(10).map do |f|
            {
              direction: f[:direction],
              magnitude: f[:magnitude],
              risk: f[:risk],
              interpretation: f[:interpretation]
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
              strength: regime[:strength],
              trend: regime[:trend]
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
