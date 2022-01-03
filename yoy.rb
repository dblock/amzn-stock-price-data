require 'rubygems'
require 'csv'
require 'date'
require 'active_support'
require 'active_support/core_ext'

class Array
    def sum
        inject(0.0) { |result, el| result + el }
    end
  
    def mean 
        result = sum / size if size
        return result&.to_i unless result.nan?
        nil
    end
end

class MarketData
    VESTING_MONTHS = [12, 18, 24, 30, 36, 42, 48]

    def initialize
        @data = {}
        CSV.foreach('data/amzn.csv', headers: true) do |row|
            row['u_close'] = row['u_close'].to_f
            @data[row['date']] = row
        end
    end

    def start_at
        Time.parse(@data.values.first['date'])
    end

    # closest closing date
    def data_at(dt)
        loop do
            return @data[dt.to_s] if @data.key?(dt.to_s)
            dt = dt + 1
            break if dt >= Date.today
        end
    end

    # amzn stock vests after 1 year, then every 6 months
    def vesting_prices(dt)
        results = {}
        year_cliff = dt
        grant_data = data_at(dt)
        u_close_base = grant_data['u_close']
        u_grant_base = grant_data['u_close']
        VESTING_MONTHS.each do |m|
            data = data_at(dt + m.months)
            next unless data
            results[m] = {
                close: data['u_close'],
                total_growth: data['u_close'] - grant_data['u_close'],
                yoy_growth: data['u_close'] * 100 / u_close_base - 100,
                grant_growth: data['u_close'] * 100 / u_grant_base - 100
            }
            # reset base to years only 
            u_close_base = results[m][:close] if [12, 24, 36, 48].include?(m)
        end
        results
    end
end

puts "Loading data ..."
data = MarketData.new

puts "Generating averages ..."
column_names = ['grant date', 'average yoy', 'average since grant']
s = CSV.generate do |csv|
    csv << column_names
    dt = data.start_at.to_date
    loop do
        puts dt.year if dt.day == 31 && dt.month == 12
        if data.data_at(dt)
            vests = data.vesting_prices(dt)
            # average yoy
            yoy = MarketData::VESTING_MONTHS.map do |m|
                (vests[m] || {})[:yoy_growth]
            end.compact.mean
            # average since grant
            grant = MarketData::VESTING_MONTHS.map do |m|
                (vests[m] || {})[:grant_growth]
            end.compact.mean
            csv << [dt.to_s, yoy, grant]
        end
        dt = dt + 1.day
        break if dt >= Time.now - 6.months
    end
end

puts "Saving data ..."
File.write('data/yoy.csv', s)

