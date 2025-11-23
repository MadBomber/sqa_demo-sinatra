# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2025-11-22

### Added
- **To Do section** in README.md with prioritized roadmap items

### Changed
- Documentation updates and cleanup

## [0.2.1] - 2025-11-22

### Changed
- **Major refactoring** of `app.rb` from 902 lines to 50 lines for improved maintainability
- Extracted helpers into separate modules under `helpers/` directory:
  - `formatting.rb` - Value formatting helpers (currency, percent, numbers)
  - `filters.rb` - Time period filtering for data arrays
  - `stock_loader.rb` - Centralized stock data loading and calculations
  - `api_helpers.rb` - API-specific helpers (indicators, patterns, FPOP analysis)
- Extracted routes into separate modules under `routes/` directory:
  - `pages.rb` - Page routes (/, /dashboard, /analyze, /backtest, /company, /compare)
  - `api.rb` - API routes (/api/stock, /api/indicators, /api/backtest, /api/analyze, /api/compare)
- Centralized stock data fetching to eliminate code duplication across routes
- Added reusable helper methods for common calculations:
  - `load_stock` and `load_stock_with_overview` for stock loading
  - `extract_ohlcv` for OHLCV data extraction
  - `calculate_price_metrics`, `calculate_indicators`, `calculate_risk_metrics`
  - `fetch_comparison_data` for parallel comparison fetching

## [0.2.0] - 2025-11-22

### Added
- **Multi-stock comparison page** (`/compare`) for side-by-side analysis of up to 5 stocks
  - Enter multiple tickers separated by spaces in search input
  - Automatic routing to comparison page when multiple tickers entered
  - Compare dropdown menu in navigation with popular comparison presets
- **Comprehensive comparison table** with 7 metric sections:
  - Price & Performance (current price, daily change, YTD return, 52-week high/low, volume)
  - Momentum Indicators (RSI, MACD, Stochastic, Momentum, ROC, CCI, Williams %R)
  - Trend Indicators (ADX, SMA 50/200, EMA 20)
  - Volatility (ATR, Bollinger Bands, Beta)
  - Valuation (P/E, Forward P/E, PEG, Price/Book, Market Cap)
  - Profitability (EPS, Profit Margin, Operating Margin, ROE, ROA, Dividend Yield)
  - Risk Metrics (Sharpe Ratio, Max Drawdown, Analyst Target)
- **Best Count summary row** at top of comparison table showing total "best" results per stock
- **Smart column ordering** - stocks sorted by best count (highest to lowest), alphabetically for ties
- **Best value highlighting** - green highlight for best performer in each metric row
- **Parallel data fetching** using threads for faster multi-stock loading
- **Partial failure handling** - shows warning for failed tickers while displaying available data
- Individual analysis links for each compared stock (Dashboard, Analysis, Company)

### Changed
- Search input placeholder updated to indicate multi-ticker support
- Added hint text explaining comparison feature (up to 5 tickers)
- Missing data now displays as "-" instead of "N/A" for cleaner presentation

## [0.1.2] - 2025-11-22

### Added
- **Sticky two-tier navigation header** that remains fixed at top while scrolling
  - Primary navbar with dropdown menus for Dashboard, Analysis, and Backtest
  - Quick access to popular stocks (AAPL, MSFT, GOOGL, TSLA) in dropdowns
  - Global search button for ticker lookup
- **Context bar** on stock-specific pages showing:
  - Current ticker symbol and company name
  - Sub-navigation pills (Dashboard, Analysis, Backtest, Company)
  - Period selector dropdown (on Dashboard)
- **Enhanced FPOP (Future Period Analysis) table**:
  - Date column showing prediction target dates
  - Historical predictions with actual price change verification
  - Green checkmark for correct predictions (within 1% of actual)
  - Red X for incorrect predictions
  - Future predictions marked as "Pending" with cyan highlight
  - Accuracy summary showing historical prediction success rate
  - Weekend-aware future date generation (skips Sat/Sun)

### Changed
- Navigation now uses consistent menubar across all pages
- FPOP predictions now show both historical (verifiable) and future dates
- Prediction accuracy based on magnitude difference (<=1% = correct)

## [0.1.1] - 2025-11-22

### Added
- Company details page (`/company/:ticker`) with comprehensive stock overview
- Company name display on dashboard header with link to details page
- Full company profile including description, sector, industry, financials
- Analyst ratings display (Strong Buy/Buy/Hold/Sell/Strong Sell)
- Dividend information section
- Share information (outstanding, float, insider/institutional ownership)

### Fixed
- Market regime API now returns numeric `strength_score` and `trend_score` values
- Analysis page now displays regime data correctly

## [0.1.0] - 2025-11-22

### Added
- Initial release of SQA Demo Sinatra application
- Interactive stock dashboard with candlestick charts
- Technical indicators support:
  - SMA (Simple Moving Average) with multiple periods
  - EMA (Exponential Moving Average)
  - Bollinger Bands
  - RSI (Relative Strength Index)
  - MACD (Moving Average Convergence Divergence)
  - Stochastic Oscillator
  - CCI (Commodity Channel Index)
  - ADX (Average Directional Index)
  - Volume indicators (OBV, Volume SMA)
- Candlestick pattern recognition:
  - Doji patterns
  - Hammer and Hanging Man
  - Engulfing patterns (Bullish/Bearish)
  - Morning Star and Evening Star
  - Three White Soldiers and Three Black Crows
- Market analysis features:
  - Market regime detection (Bull/Bear/Sideways)
  - Seasonal pattern analysis
  - FPOP (Future Period of Probability) analysis
  - Risk metrics (VaR, Sharpe Ratio, Max Drawdown)
- Backtest functionality for trading strategies
- Portfolio optimizer page
- Responsive dark-themed UI with ApexCharts
- RESTful API endpoints for stock data and analysis
- Development hot-reloader support
- Startup script for easy deployment

[Unreleased]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/madbomber/sqa_demo-sinatra/releases/tag/v0.1.0
