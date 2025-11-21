# frozen_string_literal: true

require_relative 'test_helper'

class AppTest < Minitest::Test
  include TestHelper

  def test_home_page_returns_success
    get '/'
    assert last_response.ok?
  end

  def test_home_page_contains_sqa_title
    get '/'
    assert_includes last_response.body, 'SQA'
  end

  def test_dashboard_page_returns_success
    get '/dashboard/AAPL'
    assert last_response.ok?
  end

  def test_analyze_page_returns_success
    get '/analyze/AAPL'
    assert last_response.ok?
  end

  def test_backtest_page_returns_success
    get '/backtest/AAPL'
    assert last_response.ok?
  end

  def test_api_stock_returns_json
    get '/api/stock/AAPL'
    assert last_response.ok?
    assert_equal 'application/json', last_response.content_type
  end
end
