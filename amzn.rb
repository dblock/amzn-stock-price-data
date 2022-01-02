require 'rubygems'
require 'csv'
require 'iex-ruby-client'

IEX::Api.configure do |config|
    config.publishable_token = 'get your own token from iexcloud'
    config.endpoint = 'https://cloud.iexapis.com/v1' 
    # config.publishable_token = 'Tpk_a85f7a66e0304c4db401f90ab1345254'
    # config.endpoint = 'https://sandbox.iexapis.com/v1'
  end

client = IEX::Api::Client.new

# 10 years of AMZN stock
historical_prices = client.historical_prices('AMZN', { range: '10y', chartByDay: true }) 

column_names = historical_prices.first.keys
s = CSV.generate do |csv|
  csv << column_names
  historical_prices.each do |x|
    csv << x.values
  end
end

File.write('data/amzn.csv', s)
