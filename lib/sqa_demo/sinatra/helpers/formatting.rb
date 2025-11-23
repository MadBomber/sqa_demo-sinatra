# frozen_string_literal: true

module SqaDemo
  module Sinatra
    module Helpers
      module Formatting
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
          return '-' if value.nil?

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
      end
    end
  end
end
