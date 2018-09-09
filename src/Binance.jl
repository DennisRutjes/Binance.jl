module Binance

import HTTP, SHA, JSON, Dates, Printf.@sprintf

apiKey = ENV["BINANCE_APIKEY"] 
apiSecret = ENV["BINANCE_SECRET"] 

# base URL of the Binance API
BINANCE_API_REST = "https://api.binance.com/"
BINANCE_API_TICKER = string(BINANCE_API_REST,"api/v1/ticker/")
BINANCE_API_KLINES = string(BINANCE_API_REST,"api/v1/klines")

BINANCE_API_WS = "wss://stream.binance.com:9443/ws/"
BINANCE_API_STREAM = "wss://stream.binance.com:9443/stream/"

# function HTTP response 2 JSON
function r2j(response)
    JSON.parse(String(response))
end

function get24HR()
    r = HTTP.request("GET", string(BINANCE_API_TICKER, "24hr"))
    r2j(r.body)    
end

function get24HR(symbol::String)
    r = HTTP.request("GET", string(BINANCE_API_TICKER, "24hr?symbol=", symbol))
    r2j(r.body)    
end

function getAllPrices()
    r = HTTP.request("GET", string(BINANCE_API_TICKER, "allPrices"))
    r2j(r.body)    
end

function getAllBookTickers()
    r = HTTP.request("GET", string(BINANCE_API_TICKER, "allBookTickers"))
    r2j(r.body)    
end

function getMarket()
    r = HTTP.request("GET", "https://www.binance.com/exchange/public/product")
    r2j(r.body)["data"]
end

function getMarket(symbol::String)
    r = HTTP.request("GET", string("https://www.binance.com/exchange/public/product?symbol=",symbol))
    r2j(r.body)["data"]
end

# binance get candlesticks/klines data
function getKlines(symbol; startDateTime=nothing, endDateTime=nothing, interval="1m")
    query = string("?symbol=", symbol, "&interval=", interval)
    
    if startDateTime != nothing && endDateTime != nothing
        startTime = @sprintf("%.0d",Dates.datetime2unix(startDateTime) * 1000)
        endTime = @sprintf("%.0d",Dates.datetime2unix(endDateTime) * 1000)
        query = string(query, "&startTime=", startTime, "&endTime=", endTime)
    end
   r = HTTP.request("GET", string(BINANCE_API_KLINES, query))
    r2j(r.body)
end


# helper
filterOnRegex(matcher, withDictArr; withKey="symbol") = filter(x-> match(Regex(matcher), x[withKey]) != nothing, withDictArr);

end
