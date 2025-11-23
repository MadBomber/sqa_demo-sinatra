# frozen_string_literal: true

require 'date'

module SqaDemo
  module Sinatra
    module Helpers
      module Filters
        # Filter data arrays by time period
        # period can be: "30d", "60d", "90d", "1q", "2q", "3q", "4q", "all"
        def filter_by_period(dates, *data_arrays, period: 'all')
          return [dates, *data_arrays] if period == 'all' || dates.empty?

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
    end
  end
end
