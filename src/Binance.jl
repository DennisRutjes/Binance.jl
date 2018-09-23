module Binance

import HTTP, SHA, JSON, Dates, Printf.@sprintf

# base URL of the Binance API
BINANCE_API_REST = "https://api.binance.com/"
BINANCE_API_TICKER = string(BINANCE_API_REST, "api/v1/ticker/")
BINANCE_API_KLINES = string(BINANCE_API_REST, "api/v1/klines")

BINANCE_API_WS = "wss://stream.binance.com:9443/ws/"
BINANCE_API_STREAM = "wss://stream.binance.com:9443/stream/"

function apiKS()
    apiKey = get(ENV, "BINANCE_APIKEY", "") 
    apiSecret = get(ENV, "BINANCE_SECRET", "")
    
    @assert apiKey != "" || apiSecret != "" "BINANCE_APIKEY/BINANCE_APISECRET should be present in the environment dictionary ENV"
    
    apiKey, apiSecret
end


# signing with apiKey and apiSecret
function timestamp()
    Int64(floor(Dates.datetime2unix(Dates.now(Dates.UTC)) * 1000))
end

function hmac(key::Vector{UInt8}, msg::Vector{UInt8}, hash, blocksize::Int=64)
    if length(key) > blocksize
        key = hash(key)
    end

    pad = blocksize - length(key)

    if pad > 0
        resize!(key, blocksize)
        key[end - pad + 1:end] = 0
    end

    o_key_pad = key .⊻ 0x5c
    i_key_pad = key .⊻ 0x36

    hash([o_key_pad; hash([i_key_pad; msg])])
end

function doSign(queryString, apiSecret)
    bytes2hex(hmac(Vector{UInt8}(apiSecret), Vector{UInt8}(queryString), SHA.sha256))
end


# function HTTP response 2 JSON
function r2j(response)
    JSON.parse(String(response))
end

##################### PUBLIC CALL's #####################
# Simpe test if binance API is online
function ping()
    r = HTTP.request("GET", string(API_REST, "api/v1/ping"))
    r.status
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
    r = HTTP.request("GET", string("https://www.binance.com/exchange/public/product?symbol=", symbol))
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

##################### SECURED CALL's NEEDS apiKey / apiSecret #####################

function account(apiKey, apiSecret)
    headers = Dict("X-MBX-APIKEY" => apiKey)

    query = string("recvWindow=5000&timestamp=", timestamp()) 
    r = HTTP.request("GET", string(BINANCE_API_REST, "api/v3/account?", query, "&signature=", doSign(query, apiSecret)), headers)
    status = r.status
    if status != 200
        println(r)
        return {"error", status}
    end

    return r2j(r.body)
end


# helper
filterOnRegex(matcher, withDictArr; withKey="symbol") = filter(x -> match(Regex(matcher), x[withKey]) != nothing, withDictArr);

end
