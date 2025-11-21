# SQA Demo - Sinatra Web Application

A modern web interface for the SQA (Simple Qualitative Analysis) stock analysis library. Built with Sinatra, featuring interactive charts powered by ApexCharts.js, and a responsive UI for comprehensive stock market analysis.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sqa_demo-sinatra'
```

Or install it directly:

```bash
gem install sqa_demo-sinatra
```

### Prerequisites

- Ruby >= 3.2
- TA-Lib library (for technical indicators)
- Redis (for KBS strategy)

### Install TA-Lib

**macOS:**
```bash
brew install ta-lib
```

**Ubuntu/Debian:**
```bash
sudo apt-get install ta-lib-dev
```

### Set Up API Keys

SQA supports two data sources:

**Option 1: Alpha Vantage (Recommended)**
```bash
export AV_API_KEY="your_api_key_here"
```
Get a free API key from [Alpha Vantage](https://www.alphavantage.co/support/#api-key)

**Option 2: Yahoo Finance**
No API key required, but less reliable and may have rate limits.

## Usage

### Start the Application

```bash
bundle exec rackup
```

Or use the CLI executable:

```bash
sqa_sinatra              # Default port 9292
sqa_sinatra -p 4567      # Custom port
sqa_sinatra --help       # Show options
```

Or with the startup script:

```bash
./start.sh
```

The application will start on `http://localhost:9292`

### Navigate the App

1. **Home Page** - Quick access to popular stocks
2. **Search** - Enter any ticker symbol (e.g., AAPL, MSFT, GOOGL)
3. **Dashboard** - View charts and indicators
4. **Analysis** - Market regime, seasonal patterns, FPOP
5. **Backtest** - Test trading strategies

### Keyboard Shortcuts

- `Ctrl/Cmd + K` - Open ticker search modal
- `Escape` - Close modal

## Features

### Interactive Dashboard
- **Candlestick & Line Charts** - Visualize price movements with professional financial charts
- **Volume Analysis** - Track trading volume with color-coded bars
- **Technical Indicators** - RSI, MACD, SMA, EMA, Bollinger Bands
- **Key Metrics** - 52-week high/low, current RSI, market regime
- **Real-time Data** - Fetch latest stock data from Alpha Vantage or Yahoo Finance

### Strategy Backtesting
- **6 Built-in Strategies** - RSI, MACD, SMA, EMA, Bollinger Bands, KBS
- **Detailed Metrics** - Total return, Sharpe ratio, max drawdown, win rate
- **Strategy Comparison** - Compare all strategies side-by-side
- **Performance Analytics** - Profit factor, average win/loss, total trades

### Market Analysis
- **Market Regime Detection** - Identify bull/bear/sideways markets
- **Seasonal Patterns** - Discover best months and quarters for trading
- **FPOP Analysis** - Future Period Loss/Profit projections
- **Risk Metrics** - VaR, Sharpe ratio, maximum drawdown

## API Endpoints

| Route | Method | Description |
|-------|--------|-------------|
| `/` | GET | Home page with quick links |
| `/dashboard/:ticker` | GET | Main dashboard for ticker |
| `/analyze/:ticker` | GET | Market analysis page |
| `/backtest/:ticker` | GET | Strategy backtesting page |
| `/portfolio` | GET | Portfolio optimization (coming soon) |
| `/api/stock/:ticker` | GET | Get stock data |
| `/api/indicators/:ticker` | GET | Get technical indicators |
| `/api/backtest/:ticker` | POST | Run strategy backtest |
| `/api/analyze/:ticker` | GET | Get market analysis |
| `/api/compare/:ticker` | POST | Compare all strategies |

## Development

After checking out the repo, run `bundle install` to install dependencies.

```bash
# Install dependencies
bundle install

# Run the server
bundle exec rackup

# Run with auto-reload
bundle exec rerun 'rackup'

# Run tests
bundle exec rake test
```

## Technology Stack

### Backend
- **Sinatra** - Lightweight Ruby web framework
- **SQA Library** - Stock analysis and backtesting
- **TA-Lib** - Technical analysis indicators (via sqa-tai gem)
- **Polars** - High-performance DataFrame operations
- **Redis** - KBS blackboard persistence

### Frontend
- **ApexCharts.js** - Interactive financial charts
- **Font Awesome** - Icons
- **Vanilla JavaScript** - No framework dependencies
- **CSS3** - Modern styling with gradients and animations

## File Structure

```
sqa_demo-sinatra/
├── bin/
│   └── sqa_sinatra              # CLI executable
├── lib/
│   └── sqa_demo/
│       ├── sinatra.rb           # Main entry point
│       └── sinatra/
│           ├── app.rb           # Sinatra application class
│           ├── version.rb       # Version constant
│           ├── helpers/         # Helper modules
│           ├── routes/          # Route modules
│           ├── views/           # ERB templates
│           │   ├── layout.erb
│           │   ├── index.erb
│           │   ├── dashboard.erb
│           │   ├── analyze.erb
│           │   ├── backtest.erb
│           │   ├── portfolio.erb
│           │   └── error.erb
│           └── public/          # Static assets
│               ├── css/style.css
│               ├── js/app.js
│               └── images/
├── test/                        # Minitest tests
├── config.ru                    # Rack config
├── Gemfile
├── Rakefile
└── sqa_demo-sinatra.gemspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/madbomber/sqa_demo-sinatra.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This software is for educational and research purposes only. Do not use for actual trading without proper due diligence. The authors are not responsible for financial losses.
