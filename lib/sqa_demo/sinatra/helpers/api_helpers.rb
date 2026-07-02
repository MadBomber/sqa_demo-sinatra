# frozen_string_literal: true

require 'date'

module SqaDemo
  module Sinatra
    module Helpers
      module ApiHelpers
        # GET /api/stock/:ticker - basic OHLCV stats filtered by period
        def api_stock_response(ticker_param, period_param)
          ticker = ticker_param.upcase
          period = period_param || 'all'

          stock = SQA::Stock.new(ticker: ticker)
          ohlcv = extract_ohlcv(stock)

          filtered = filter_by_period(
            ohlcv[:dates], ohlcv[:opens], ohlcv[:highs], ohlcv[:lows], ohlcv[:closes], ohlcv[:volumes],
            period: period
          )

          build_stock_payload(ticker, period, ohlcv, filtered).to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end

        # GET /api/indicators/:ticker - technical indicators + candlestick patterns filtered by period
        def api_indicators_response(ticker_param, period_param)
          ticker = ticker_param.upcase
          period = period_param || 'all'

          stock = SQA::Stock.new(ticker: ticker)
          ohlcv = extract_ohlcv(stock)
          n = ohlcv[:closes].length

          indicators = calculate_all_indicators(ohlcv[:opens], ohlcv[:highs], ohlcv[:lows], ohlcv[:closes], ohlcv[:volumes], n)
          detected_patterns = detect_candlestick_patterns(ohlcv[:opens], ohlcv[:highs], ohlcv[:lows], ohlcv[:closes], ohlcv[:dates], n)
          filtered_data = filter_indicators_by_period(ohlcv[:dates], indicators, period)

          filtered_data.merge(
            period: period,
            patterns: detected_patterns
          ).to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end

        # POST /api/backtest/:ticker - run a single strategy backtest
        def api_backtest_response(ticker_param, strategy_param)
          ticker = ticker_param.upcase
          strategy_name = strategy_param || 'RSI'

          stock = SQA::Stock.new(ticker: ticker)
          strategy = resolve_strategy(strategy_name)

          backtest = SQA::Backtest.new(
            stock: stock,
            strategy: strategy,
            initial_capital: 10_000.0,
            commission: 1.0
          )

          backtest_result_payload(backtest.run).to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end

        # GET /api/analyze/:ticker - market regime, seasonal, FPOP, and risk analysis
        def api_analyze_response(ticker_param)
          ticker = ticker_param.upcase

          stock = SQA::Stock.new(ticker: ticker)
          prices = stock.df["adj_close_price"].to_a

          regime = SQA::MarketRegime.detect(stock)
          seasonal = SQA::SeasonalAnalyzer.analyze(stock)
          fpop_results = analyze_fpop(stock, prices)
          risk = calculate_analyze_risk_metrics(prices)

          {
            regime: regime_payload(regime),
            seasonal: seasonal_payload(seasonal),
            fpop: fpop_results,
            risk: risk
          }.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end

        # POST /api/compare/:ticker - backtest several strategies and rank by return
        def api_compare_response(ticker_param)
          ticker = ticker_param.upcase
          stock = SQA::Stock.new(ticker: ticker)

          results = comparable_strategies.map do |name, strategy_class|
            strategy_comparison_result(stock, name, strategy_class)
          rescue
            nil
          end.compact

          results.sort_by! { |r| -r[:return] }
          results.to_json
        rescue => e
          status 500
          { error: e.message }.to_json
        end

        # Resolve strategy name to class
        def resolve_strategy(strategy_name)
          case strategy_name.upcase
          when 'SMA' then SQA::Strategy::SMA
          when 'EMA' then SQA::Strategy::EMA
          when 'MACD' then SQA::Strategy::MACD
          when 'BOLLINGERBANDS' then SQA::Strategy::BollingerBands
          when 'KBS' then SQA::Strategy::KBS
          else SQA::Strategy::RSI # 'RSI' and any unrecognized name both fall back to RSI
          end
        end

        # Calculate all technical indicators
        def calculate_all_indicators(opens, highs, lows, prices, volumes, n)
          pad_array = indicator_padder(n)

          price_indicators(prices, pad_array)
            .merge(moving_averages(prices, pad_array))
            .merge(momentum_indicators(highs, lows, prices, pad_array))
            .merge(volatility_indicators(highs, lows, prices, pad_array))
            .merge(volume_indicators(highs, lows, prices, volumes, pad_array))
        end

        # Detect candlestick patterns
        def detect_candlestick_patterns(opens, highs, lows, prices, dates, n)
          pad_array = indicator_padder(n)
          pattern_defs = candlestick_pattern_defs(opens, highs, lows, prices, pad_array)

          detected_patterns = pattern_defs.flat_map do |_key, pdef|
            candlestick_matches(pdef, dates)
          end

          detected_patterns.sort_by! { |p| p[:date] }.reverse!
          detected_patterns.first(20)
        end

        # Filter indicators by period
        def filter_indicators_by_period(dates, indicators, period)
          all_arrays = [dates] + indicators.values
          filtered = filter_by_period(*all_arrays, period: period)

          result = { dates: filtered[0] }
          indicators.keys.each_with_index do |key, i|
            result[key] = filtered[i + 1]
          end
          result
        end

        # Analyze FPOP (Future Period Loss/Profit)
        def analyze_fpop(stock, prices)
          dates = stock.df["timestamp"].to_a.map(&:to_s)
          fpop_period = 10
          fpop_data = SQA::FPOP.fpl_analysis(prices, fpop: fpop_period)
          future_dates = future_trading_dates(dates.last, fpop_period)

          fpop_historical_predictions(dates, prices, fpop_data) +
            fpop_future_predictions(fpop_data, future_dates, fpop_period)
        end

        private

        # Compute each candlestick indicator series and pair it with its display metadata
        def candlestick_pattern_defs(opens, highs, lows, prices, pad_array)
          series = ->(method) { pad_array.call(SQAI.public_send(method, opens, highs, lows, prices)) }

          {
            doji: { data: series.call(:cdl_doji), name: 'Doji', type: :neutral },
            hammer: { data: series.call(:cdl_hammer), name: 'Hammer', type: :fixed, signal: 'bullish' },
            shootingstar: { data: series.call(:cdl_shootingstar), name: 'Shooting Star', type: :fixed, signal: 'bearish' },
            engulfing: { data: series.call(:cdl_engulfing), name: 'Engulfing', type: :directional },
            morningstar: { data: series.call(:cdl_morningstar), name: 'Morning Star', type: :fixed, signal: 'bullish' },
            eveningstar: { data: series.call(:cdl_eveningstar), name: 'Evening Star', type: :fixed, signal: 'bearish' },
            harami: { data: series.call(:cdl_harami), name: 'Harami', type: :directional },
            whitesoldiers: { data: series.call(:cdl_3whitesoldiers), name: 'Three White Soldiers', type: :fixed, signal: 'bullish' },
            blackcrows: { data: series.call(:cdl_3blackcrows), name: 'Three Black Crows', type: :fixed, signal: 'bearish' },
            piercing: { data: series.call(:cdl_piercing), name: 'Piercing', type: :fixed, signal: 'bullish' },
            darkcloudcover: { data: series.call(:cdl_darkcloudcover), name: 'Dark Cloud Cover', type: :fixed, signal: 'bearish' },
            marubozu: { data: series.call(:cdl_marubozu), name: 'Marubozu', type: :directional }
          }
        end

        # Build detected-pattern entries for a single pattern definition across all days
        def candlestick_matches(pdef, dates)
          pdef[:data].each_with_index.filter_map do |val, i|
            next if val.nil? || val.zero?

            {
              date: dates[i],
              pattern: pdef[:name],
              signal: candlestick_signal(pdef, val),
              strength: val.abs
            }
          end
        end

        # Resolve the bullish/bearish/neutral signal for one candlestick match
        def candlestick_signal(pdef, val)
          case pdef[:type]
          when :neutral then 'neutral'
          when :fixed then pdef[:signal]
          when :directional then val.positive? ? 'bullish' : 'bearish'
          end
        end

        # Generate the next `count` weekday (trading) dates after `last_date_str`
        def future_trading_dates(last_date_str, count)
          last_date = Date.parse(last_date_str)
          future_dates = []
          current_date = last_date + 1

          while future_dates.length < count
            future_dates << current_date.to_s unless current_date.saturday? || current_date.sunday?
            current_date += 1
          end

          future_dates
        end

        # Build the last few historical FPOP predictions, verified against actual price moves
        def fpop_historical_predictions(dates, prices, fpop_data)
          num_historical = [5, dates.length - 1].min
          hist_start = dates.length - num_historical - 1

          (0...num_historical).filter_map do |i|
            idx = hist_start + i
            target_idx = idx + 1
            next if idx.negative? || idx >= fpop_data.length || target_idx >= prices.length

            fpop_historical_entry(dates, prices, fpop_data, idx, target_idx)
          end
        end

        # Build a single verified historical FPOP entry
        def fpop_historical_entry(dates, prices, fpop_data, idx, target_idx)
          prev_price = prices[idx]
          actual_price = prices[target_idx]
          actual_change = ((actual_price - prev_price) / prev_price) * 100
          actual_direction = if actual_change > 0.1
                               'UP'
                             else
                               (actual_change < -0.1 ? 'DOWN' : 'FLAT')
                             end

          predicted_magnitude = fpop_data[idx][:magnitude]
          correct = (predicted_magnitude - actual_change).abs <= 1.0

          {
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

        # Build the upcoming (unverifiable) FPOP predictions
        def fpop_future_predictions(fpop_data, future_dates, fpop_period)
          fpop_data.last(fpop_period).each_with_index.map do |f, i|
            {
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
        end

        # Build a padder lambda that left-pads indicator arrays to the full dataset length
        def indicator_padder(n)
          ->(arr) { Array.new(n - arr.length, nil) + arr }
        end

        # RSI, MACD, and Bollinger Bands
        def price_indicators(prices, pad_array)
          macd_result = SQAI.macd(prices)
          bb_result = SQAI.bbands(prices)

          {
            rsi: pad_array.call(SQAI.rsi(prices, period: 14)),
            macd: pad_array.call(macd_result[0]),
            macd_signal: pad_array.call(macd_result[1]),
            macd_hist: pad_array.call(macd_result[2]),
            bb_upper: pad_array.call(bb_result[0]),
            bb_middle: pad_array.call(bb_result[1]),
            bb_lower: pad_array.call(bb_result[2])
          }
        end

        # SMA/EMA/WMA/DEMA/TEMA/KAMA moving averages
        def moving_averages(prices, pad_array)
          {
            sma_12: pad_array.call(SQAI.sma(prices, period: 12)),
            sma_20: pad_array.call(SQAI.sma(prices, period: 20)),
            sma_50: pad_array.call(SQAI.sma(prices, period: 50)),
            ema_20: pad_array.call(SQAI.ema(prices, period: 20)),
            wma_20: pad_array.call(SQAI.wma(prices, period: 20)),
            dema_20: pad_array.call(SQAI.dema(prices, period: 20)),
            tema_20: pad_array.call(SQAI.tema(prices, period: 20)),
            kama_30: pad_array.call(SQAI.kama(prices, period: 30))
          }
        end

        # Stochastic, momentum, CCI, Williams %R, ROC, ADX
        def momentum_indicators(highs, lows, prices, pad_array)
          stoch_result = SQAI.stoch(highs, lows, prices)

          {
            stoch_slowk: pad_array.call(stoch_result[0]),
            stoch_slowd: pad_array.call(stoch_result[1]),
            mom_10: pad_array.call(SQAI.mom(prices, period: 10)),
            cci_14: pad_array.call(SQAI.cci(highs, lows, prices, period: 14)),
            willr_14: pad_array.call(SQAI.willr(highs, lows, prices, period: 14)),
            roc_10: pad_array.call(SQAI.roc(prices, period: 10)),
            adx_14: pad_array.call(SQAI.adx(highs, lows, prices, period: 14))
          }
        end

        # Average True Range
        def volatility_indicators(highs, lows, prices, pad_array)
          { atr_14: pad_array.call(SQAI.atr(highs, lows, prices, period: 14)) }
        end

        # OBV, Chaikin A/D, and volume moving averages
        def volume_indicators(highs, lows, prices, volumes, pad_array)
          {
            obv: pad_array.call(SQAI.obv(prices, volumes)),
            ad: pad_array.call(SQAI.ad(highs, lows, prices, volumes)),
            vol_sma_12: pad_array.call(SQAI.sma(volumes, period: 12)),
            vol_sma_20: pad_array.call(SQAI.sma(volumes, period: 20)),
            vol_sma_50: pad_array.call(SQAI.sma(volumes, period: 50)),
            vol_ema_12: pad_array.call(SQAI.ema(volumes, period: 12)),
            vol_ema_20: pad_array.call(SQAI.ema(volumes, period: 20))
          }
        end

        # Build the JSON-ready payload for the /api/stock/:ticker response
        def build_stock_payload(ticker, period, ohlcv, filtered)
          filtered_dates, filtered_opens, filtered_highs, filtered_lows, filtered_closes, filtered_volumes = filtered

          current_price = filtered_closes.last
          prev_price = filtered_closes[-2]
          change = current_price - prev_price
          change_pct = (change / prev_price) * 100

          # 52-week high/low uses full data for reference
          high_52w = ohlcv[:closes].last(252).max rescue ohlcv[:closes].max
          low_52w = ohlcv[:closes].last(252).min rescue ohlcv[:closes].min

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
          }
        end

        # Build the JSON-ready payload for a single backtest run
        def backtest_result_payload(results)
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
          }
        end

        # Risk metrics block used by the /api/analyze/:ticker response
        def calculate_analyze_risk_metrics(prices)
          returns = prices.each_cons(2).map { |a, b| (b - a) / a }

          {
            var_95: SQA::RiskManager.var(returns, confidence: 0.95),
            sharpe_ratio: SQA::RiskManager.sharpe_ratio(returns),
            max_drawdown: SQA::RiskManager.max_drawdown(prices)[:max_drawdown]
          }
        end

        # Regime block used by the /api/analyze/:ticker response
        def regime_payload(regime)
          {
            type: regime[:type],
            volatility: regime[:volatility],
            strength: regime[:strength_score],
            trend: regime[:trend_score]
          }
        end

        # Seasonal block used by the /api/analyze/:ticker response
        def seasonal_payload(seasonal)
          {
            best_months: seasonal[:best_months],
            worst_months: seasonal[:worst_months],
            best_quarters: seasonal[:best_quarters],
            has_pattern: seasonal[:has_seasonal_pattern]
          }
        end

        # Strategy classes available for the /api/compare/:ticker response
        def comparable_strategies
          {
            'RSI' => SQA::Strategy::RSI,
            'SMA' => SQA::Strategy::SMA,
            'EMA' => SQA::Strategy::EMA,
            'MACD' => SQA::Strategy::MACD,
            'BollingerBands' => SQA::Strategy::BollingerBands
          }
        end

        # Run and summarize one strategy's backtest for the compare response
        def strategy_comparison_result(stock, name, strategy_class)
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
        end
      end
    end
  end
end
