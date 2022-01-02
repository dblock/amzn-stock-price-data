require 'rubygems'
require 'csv'
require 'date'
require 'active_support'
require 'active_support/core_ext'

class MarketData
    VESTING_MONTHS = [12, 18, 24, 30, 36, 42, 48]

    def initialize
        @data = {}
        CSV.foreach('amzn.csv', headers: true) do |row|
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
        VESTING_MONTHS.each do |m|
            data = data_at(dt + m.months)
            next unless data
            results[m] = {
                close: data['u_close'],
                total_growth: data['u_close'] - grant_data['u_close'],
                yoy_growth: data['u_close'] * 100 / u_close_base - 100
            }
            # reset base to years only 
            u_close_base = results[m][:close] if [12, 24, 36, 48].include?(m)
        end
        results
    end
end

column_names = ['date', 'avg'] + MarketData::VESTING_MONTHS.map(&:to_s)
s = CSV.generate do |csv|
    csv << column_names

    data = MarketData.new
    dt = data.start_at.to_date
    loop do
        next unless data.data_at(dt)
        vests = data.vesting_prices(dt)
        yoy = MarketData::VESTING_MONTHS.map do |m|
            vests.key?(m) ? vests[m][:yoy_growth].to_i : nil
        end.compact
        csv << [dt.to_s, (yoy.sum(0.0) / yoy.size).to_i] + yoy if yoy.any?
        dt = dt + 1.day
        break if dt >= Time.now - 6.months
    end
end

File.write('data/yoy.csv', s)
