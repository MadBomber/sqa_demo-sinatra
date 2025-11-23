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

            ticker = params[:ticker].upcase
            period = params[:period] || 'all'

            begin
              stock = SQA::Stock.new(ticker: ticker)
              ohlcv = extract_ohlcv(stock)

              # Filter by period
              filtered_dates, filtered_opens, filtered_highs, filtered_lows, filtered_closes, filtered_volumes =
                filter_by_period(ohlcv[:dates], ohlcv[:opens], ohlcv[:highs], ohlcv[:lows], ohlcv[:closes], ohlcv[:volumes], period: period)

              # Calculate basic stats
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
              }.to_json
            rescue => e
              status 500
              { error: e.message }.to_json
            end
          end

          # Get technical indicators
          app.get '/api/indicators/:ticker' do
            content_type :json

            ticker = params[:ticker].upcase
            period = params[:period] || 'all'

            begin
              stock = SQA::Stock.new(ticker: ticker)
              ohlcv = extract_ohlcv(stock)

              prices = ohlcv[:closes]
              opens = ohlcv[:opens]
              highs = ohlcv[:highs]
              lows = ohlcv[:lows]
              volumes = ohlcv[:volumes]
              dates = ohlcv[:dates]
              n = prices.length

              # Calculate indicators on full dataset (they need historical context)
              indicators = calculate_all_indicators(opens, highs, lows, prices, volumes, n)

              # Detect candlestick patterns
              detected_patterns = detect_candlestick_patterns(opens, highs, lows, prices, dates, n)

              # Filter results by period
              filtered_data = filter_indicators_by_period(dates, indicators, period)

              filtered_data.merge(
                period: period,
                patterns: detected_patterns
              ).to_json
            rescue => e
              status 500
              { error: e.message }.to_json
            end
          end

          # Run backtest
          app.post '/api/backtest/:ticker' do
            content_type :json

            ticker = params[:ticker].upcase
            strategy_name = params[:strategy] || 'RSI'

            begin
              stock = SQA::Stock.new(ticker: ticker)

              # Resolve strategy
              strategy = resolve_strategy(strategy_name)

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
          app.get '/api/analyze/:ticker' do
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
              fpop_results = analyze_fpop(stock, prices)

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
                fpop: fpop_results,
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
          app.post '/api/compare/:ticker' do
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
  end
end
