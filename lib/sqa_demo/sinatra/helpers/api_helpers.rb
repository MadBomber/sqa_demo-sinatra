# frozen_string_literal: true

require 'date'

module SqaDemo
  module Sinatra
    module Helpers
      module ApiHelpers
        # Resolve strategy name to class
        def resolve_strategy(strategy_name)
          case strategy_name.upcase
          when 'RSI' then SQA::Strategy::RSI
          when 'SMA' then SQA::Strategy::SMA
          when 'EMA' then SQA::Strategy::EMA
          when 'MACD' then SQA::Strategy::MACD
          when 'BOLLINGERBANDS' then SQA::Strategy::BollingerBands
          when 'KBS' then SQA::Strategy::KBS
          else SQA::Strategy::RSI
          end
        end

        # Calculate all technical indicators
        def calculate_all_indicators(opens, highs, lows, prices, volumes, n)
          pad_array = ->(arr) { Array.new(n - arr.length, nil) + arr }

          # Price indicators
          rsi = pad_array.call(SQAI.rsi(prices, period: 14))
          macd_result = SQAI.macd(prices)
          macd_line = pad_array.call(macd_result[0])
          macd_signal = pad_array.call(macd_result[1])
          macd_hist = pad_array.call(macd_result[2])

          bb_result = SQAI.bbands(prices)
          bb_upper = pad_array.call(bb_result[0])
          bb_middle = pad_array.call(bb_result[1])
          bb_lower = pad_array.call(bb_result[2])

          # Moving averages
          sma_12 = pad_array.call(SQAI.sma(prices, period: 12))
          sma_20 = pad_array.call(SQAI.sma(prices, period: 20))
          sma_50 = pad_array.call(SQAI.sma(prices, period: 50))
          ema_20 = pad_array.call(SQAI.ema(prices, period: 20))
          wma_20 = pad_array.call(SQAI.wma(prices, period: 20))
          dema_20 = pad_array.call(SQAI.dema(prices, period: 20))
          tema_20 = pad_array.call(SQAI.tema(prices, period: 20))
          kama_30 = pad_array.call(SQAI.kama(prices, period: 30))

          # Momentum indicators
          stoch_result = SQAI.stoch(highs, lows, prices)
          stoch_slowk = pad_array.call(stoch_result[0])
          stoch_slowd = pad_array.call(stoch_result[1])
          mom_10 = pad_array.call(SQAI.mom(prices, period: 10))
          cci_14 = pad_array.call(SQAI.cci(highs, lows, prices, period: 14))
          willr_14 = pad_array.call(SQAI.willr(highs, lows, prices, period: 14))
          roc_10 = pad_array.call(SQAI.roc(prices, period: 10))
          adx_14 = pad_array.call(SQAI.adx(highs, lows, prices, period: 14))

          # Volatility indicators
          atr_14 = pad_array.call(SQAI.atr(highs, lows, prices, period: 14))

          # Volume indicators
          obv = pad_array.call(SQAI.obv(prices, volumes))
          ad = pad_array.call(SQAI.ad(highs, lows, prices, volumes))
          vol_sma_12 = pad_array.call(SQAI.sma(volumes, period: 12))
          vol_sma_20 = pad_array.call(SQAI.sma(volumes, period: 20))
          vol_sma_50 = pad_array.call(SQAI.sma(volumes, period: 50))
          vol_ema_12 = pad_array.call(SQAI.ema(volumes, period: 12))
          vol_ema_20 = pad_array.call(SQAI.ema(volumes, period: 20))

          {
            rsi: rsi, macd: macd_line, macd_signal: macd_signal, macd_hist: macd_hist,
            bb_upper: bb_upper, bb_middle: bb_middle, bb_lower: bb_lower,
            sma_12: sma_12, sma_20: sma_20, sma_50: sma_50, ema_20: ema_20,
            wma_20: wma_20, dema_20: dema_20, tema_20: tema_20, kama_30: kama_30,
            stoch_slowk: stoch_slowk, stoch_slowd: stoch_slowd, mom_10: mom_10,
            cci_14: cci_14, willr_14: willr_14, roc_10: roc_10, adx_14: adx_14,
            atr_14: atr_14, obv: obv, ad: ad,
            vol_sma_12: vol_sma_12, vol_sma_20: vol_sma_20, vol_sma_50: vol_sma_50,
            vol_ema_12: vol_ema_12, vol_ema_20: vol_ema_20
          }
        end

        # Detect candlestick patterns
        def detect_candlestick_patterns(opens, highs, lows, prices, dates, n)
          pad_array = ->(arr) { Array.new(n - arr.length, nil) + arr }

          cdl_doji = pad_array.call(SQAI.cdl_doji(opens, highs, lows, prices))
          cdl_hammer = pad_array.call(SQAI.cdl_hammer(opens, highs, lows, prices))
          cdl_shootingstar = pad_array.call(SQAI.cdl_shootingstar(opens, highs, lows, prices))
          cdl_engulfing = pad_array.call(SQAI.cdl_engulfing(opens, highs, lows, prices))
          cdl_morningstar = pad_array.call(SQAI.cdl_morningstar(opens, highs, lows, prices))
          cdl_eveningstar = pad_array.call(SQAI.cdl_eveningstar(opens, highs, lows, prices))
          cdl_harami = pad_array.call(SQAI.cdl_harami(opens, highs, lows, prices))
          cdl_3whitesoldiers = pad_array.call(SQAI.cdl_3whitesoldiers(opens, highs, lows, prices))
          cdl_3blackcrows = pad_array.call(SQAI.cdl_3blackcrows(opens, highs, lows, prices))
          cdl_piercing = pad_array.call(SQAI.cdl_piercing(opens, highs, lows, prices))
          cdl_darkcloudcover = pad_array.call(SQAI.cdl_darkcloudcover(opens, highs, lows, prices))
          cdl_marubozu = pad_array.call(SQAI.cdl_marubozu(opens, highs, lows, prices))

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
          last_date = Date.parse(dates.last)
          fpop_period = 10
          fpop_data = SQA::FPOP.fpl_analysis(prices, fpop: fpop_period)

          # Generate future trading dates (skip weekends)
          future_dates = []
          current_date = last_date + 1
          while future_dates.length < fpop_period
            unless current_date.saturday? || current_date.sunday?
              future_dates << current_date.to_s
            end
            current_date += 1
          end

          # Show last 5 historical predictions + 10 future predictions
          num_historical = [5, dates.length - 1].min
          recent_fpop = []

          # Historical predictions with verification
          hist_start = dates.length - num_historical - 1
          (0...num_historical).each do |i|
            idx = hist_start + i
            target_idx = idx + 1
            next if idx < 0 || idx >= fpop_data.length || target_idx >= prices.length

            prev_price = prices[idx]
            actual_price = prices[target_idx]
            actual_change = ((actual_price - prev_price) / prev_price) * 100
            actual_direction = actual_change > 0.1 ? 'UP' : (actual_change < -0.1 ? 'DOWN' : 'FLAT')

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

          # Future predictions
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

          recent_fpop
        end
      end
    end
  end
end
