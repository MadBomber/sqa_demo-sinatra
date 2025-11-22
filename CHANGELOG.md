# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/madbomber/sqa_demo-sinatra/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/madbomber/sqa_demo-sinatra/releases/tag/v0.1.0
