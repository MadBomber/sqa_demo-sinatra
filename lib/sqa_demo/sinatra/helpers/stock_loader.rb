# frozen_string_literal: true

require 'sqa'
require 'date'

module SqaDemo
  module Sinatra
    module Helpers
      module StockLoader
        # Central method to load stock data and company info
        # Returns a hash with :stock, :ticker, :company_name
        # Raises an error if loading fails
        def load_stock(ticker)
          ticker = ticker.upcase
          stock = SQA::Stock.new(ticker: ticker)
          ticker_info = SQA::Ticker.lookup(ticker)
          company_name = ticker_info[:name] if ticker_info

          {
            stock: stock,
            ticker: ticker,
            company_name: company_name
          }
        end

        # Load stock with company overview (for company page and comparison)
        # Returns extended hash with :overview, :exchange
        def load_stock_with_overview(ticker)
          result = load_stock(ticker)
          stock = result[:stock]

          # Get comprehensive company overview (convert string keys to symbols)
          raw_overview = stock.overview || {}
          overview = raw_overview.transform_keys(&:to_sym)

          # Fallback to ticker lookup if overview is empty
          if overview.empty?
            ticker_info = SQA::Ticker.lookup(result[:ticker])
            company_name = ticker_info[:name]&.strip if ticker_info
            exchange = ticker_info[:exchange] if ticker_info
          else
            company_name = overview[:name]&.strip
            exchange = overview[:exchange]
          end

          result.merge(
            company_name: company_name,
            overview: overview,
            exchange: exchange
          )
        end

        # Extract common price/volume data from stock dataframe
        def extract_ohlcv(stock)
          df = stock.df
          {
            dates: df["timestamp"].to_a.map(&:to_s),
            opens: df["open_price"].to_a,
            highs: df["high_price"].to_a,
            lows: df["low_price"].to_a,
            closes: df["adj_close_price"].to_a,
            volumes: df["volume"].to_a
          }
        end

        # Calculate basic price metrics
        def calculate_price_metrics(prices)
          current_price = prices.last
          prev_price = prices[-2] || prices.last
          change = current_price - prev_price
          change_pct = prev_price > 0 ? (change / prev_price * 100) : 0

          {
            current_price: current_price,
            prev_price: prev_price,
            change: change,
            change_pct: change_pct,
            high_52w: prices.last(252).max,
            low_52w: prices.last(252).min
          }
        end

        # Calculate YTD return
        def calculate_ytd_return(dates, prices)
          current_year = Date.today.year
          ytd_prices = dates.each_with_index
                            .select { |d, _| Date.parse(d).year == current_year }
                            .map { |_, i| prices[i] }

          if ytd_prices.length > 1
            ((ytd_prices.last - ytd_prices.first) / ytd_prices.first * 100).round(2)
          end
        end

        # Calculate technical indicators for a stock
        # Returns a hash of indicator values (last value for each)
        def calculate_indicators(highs, lows, prices)
          {
            rsi: safe_indicator { SQAI.rsi(prices, period: 14).last },
            macd: safe_indicator { SQAI.macd(prices)[0].last },
            macd_signal: safe_indicator { SQAI.macd(prices)[1].last },
            macd_hist: safe_indicator { SQAI.macd(prices)[2].last },
            stoch_k: safe_indicator { SQAI.stoch(highs, lows, prices)[0].last },
            stoch_d: safe_indicator { SQAI.stoch(highs, lows, prices)[1].last },
            sma_50: safe_indicator { SQAI.sma(prices, period: 50).last },
            sma_200: safe_indicator { SQAI.sma(prices, period: 200).last },
            ema_20: safe_indicator { SQAI.ema(prices, period: 20).last },
            bb_upper: safe_indicator { SQAI.bbands(prices)[0].last },
            bb_middle: safe_indicator { SQAI.bbands(prices)[1].last },
            bb_lower: safe_indicator { SQAI.bbands(prices)[2].last },
            adx: safe_indicator { SQAI.adx(highs, lows, prices, period: 14).last },
            atr: safe_indicator { SQAI.atr(highs, lows, prices, period: 14).last },
            cci: safe_indicator { SQAI.cci(highs, lows, prices, period: 14).last },
            willr: safe_indicator { SQAI.willr(highs, lows, prices, period: 14).last },
            mom: safe_indicator { SQAI.mom(prices, period: 10).last },
            roc: safe_indicator { SQAI.roc(prices, period: 10).last }
          }
        end

        # Calculate risk metrics
        def calculate_risk_metrics(prices)
          returns = prices.each_cons(2).map { |a, b| (b - a) / a }
          sharpe = safe_indicator { SQA::RiskManager.sharpe_ratio(returns) }
          max_dd = safe_indicator { SQA::RiskManager.max_drawdown(prices) }
          max_drawdown = max_dd ? max_dd[:max_drawdown] : nil

          {
            sharpe_ratio: sharpe,
            max_drawdown: max_drawdown
          }
        end

        # Fetch all comparison data for a single ticker
        # This is used by the compare route for parallel fetching
        def fetch_comparison_data(ticker)
          data = load_stock_with_overview(ticker)
          stock = data[:stock]
          overview = data[:overview]

          ohlcv = extract_ohlcv(stock)
          prices = ohlcv[:closes]
          volumes = ohlcv[:volumes]
          dates = ohlcv[:dates]
          highs = ohlcv[:highs]
          lows = ohlcv[:lows]

          # Calculate metrics
          price_metrics = calculate_price_metrics(prices)
          indicators = calculate_indicators(highs, lows, prices)
          risk_metrics = calculate_risk_metrics(prices)

          # Average volume
          avg_volume = (volumes.sum.to_f / volumes.length).round

          [ticker, {
            ticker: ticker,
            company_name: data[:company_name],
            current_price: price_metrics[:current_price],
            change: price_metrics[:change],
            change_pct: price_metrics[:change_pct],
            high_52w: price_metrics[:high_52w],
            low_52w: price_metrics[:low_52w],
            ytd_return: calculate_ytd_return(dates, prices),
            avg_volume: avg_volume,
            # Technical indicators
            rsi: indicators[:rsi],
            macd: indicators[:macd],
            macd_signal: indicators[:macd_signal],
            macd_hist: indicators[:macd_hist],
            stoch_k: indicators[:stoch_k],
            stoch_d: indicators[:stoch_d],
            sma_50: indicators[:sma_50],
            sma_200: indicators[:sma_200],
            ema_20: indicators[:ema_20],
            bb_upper: indicators[:bb_upper],
            bb_middle: indicators[:bb_middle],
            bb_lower: indicators[:bb_lower],
            adx: indicators[:adx],
            atr: indicators[:atr],
            cci: indicators[:cci],
            willr: indicators[:willr],
            mom: indicators[:mom],
            roc: indicators[:roc],
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
            sharpe_ratio: risk_metrics[:sharpe_ratio],
            max_drawdown: risk_metrics[:max_drawdown]
          }]
        rescue => e
          [ticker, { error: e.message }]
        end

        # Safely execute indicator calculation, returning nil on error
        def safe_indicator
          yield
        rescue StandardError
          nil
        end
      end
    end
  end
end
