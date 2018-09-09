module Binance

import HTTP, SHA, JSON, Dates, Printf.@sprintf

apiKey = ENV["BINANCE_APIKEY"] 
apiSecret = ENV["BINANCE_SECRET"] 

# base URL of the Binance API
API_REST = "https://api.binance.com/"
API_WS = "wss://stream.binance.com:9443/ws/"
API_STREAM = "wss://stream.binance.com:9443/stream/"
# function HTTP response 2 JSON
function r2j(response)
    JSON.parse(String(response))
end

# retrieve data from binance for "allPrices", "24hr", "allBookTickers"
function getBinanceDataFor(withSubject)
    r = HTTP.request("GET", string(BINANCE_API_REST, withSubject))
    r2j(r.body)
    
end

# current Binance market
function getBinanceMarket()
    r = HTTP.request("GET", "https://www.binance.com/exchange/public/product")
    r2j(r.body)["data"]
end

# binance get candlesticks/klines data
function getBinanceKline(symbol, startDateTime, endDateTime ; interval="1m")
    startTime = @sprintf("%.0d",Dates.datetime2unix(startDateTime) * 1000)
    endTime = @sprintf("%.0d",Dates.datetime2unix(endDateTime) * 1000)
    query = string("symbol=", symbol, "&interval=", interval, "&startTime=", startTime, "&endTime=", endTime)
    r = HTTP.request("GET", string("https://api.binance.com/api/v1/klines?",  query))
    r2j(r.body)
end


end
