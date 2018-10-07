module Binance

import HTTP, SHA, JSON, Dates, Printf.@sprintf

# base URL of the Binance API
BINANCE_API_REST = "https://api.binance.com/"
BINANCE_API_TICKER = string(BINANCE_API_REST, "api/v1/ticker/")
BINANCE_API_KLINES = string(BINANCE_API_REST, "api/v1/klines")
BINANCE_API_USER_DATA_STREAM = string(BINANCE_API_REST, "api/v1/userDataStream")


BINANCE_API_WS = "wss://stream.binance.com:9443/ws/"
#BINANCE_API_STREAM = "wss://stream.binance.com:9443/stream/"

function apiKS()
    apiKey = get(ENV, "BINANCE_APIKEY", "")
    apiSecret = get(ENV, "BINANCE_SECRET", "")

    @assert apiKey != "" || apiSecret != "" "BINANCE_APIKEY/BINANCE_APISECRET should be present in the environment dictionary ENV"

    apiKey, apiSecret
end

function dict2Params(dict::Dict)
    params = ""
    for kv in dict
        params = string(params, "&$(kv[1])=$(kv[2])")
    end
    params[2:end]
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

# Simple test if binance API is online
function ping()
    r = HTTP.request("GET", string(BINANCE_API_REST, "api/v1/ping"))
    r.status
end

# Binance servertime
function serverTime()
    r = HTTP.request("GET", string(BINANCE_API_REST, "api/v1/time"))
    r.status
    result = r2j(r.body)

    Dates.unix2datetime(result["serverTime"] / 1000)
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
function createOrder(symbol::String, orderSide::String; 
    quantity::Float64=0.0, orderType::String = "LIMIT", 
    price::Float64=0.0, stopPrice::Float64=0.0, 
    icebergQty::Float64=0.0, newClientOrderId::String="")
      
      if quantity <= 0.0
          error("Quantity cannot be <=0 for order type.")
      end
  
      println("$orderSide => $symbol q: $quantity, p: $price ")
      
      order = Dict("symbol"           => symbol, 
                      "side"             => orderSide,
                      "type"             => orderType,
                      "quantity"         => @sprintf("%.8f", quantity),
                      "newOrderRespType" => "FULL",
                      "recvWindow"       => 10000)
  
      if newClientOrderId != ""
          order["newClientOrderId"] = newClientOrderId;
      end
  
      if orderType == "LIMIT" || orderType == "LIMIT_MAKER"
          if price <= 0.0
              error("Price cannot be <= 0 for order type.")
          end
          order["price"] =  @sprintf("%.8f", price)
      end
  
      if orderType == "STOP_LOSS" || orderType == "TAKE_PROFIT"
          if stopPrice <= 0.0
              error("StopPrice cannot be <= 0 for order type.")
          end
          order["stopPrice"] = @sprintf("%.8f", stopPrice)
      end
  
      if orderType == "STOP_LOSS_LIMIT" || orderType == "TAKE_PROFIT_LIMIT"
          if price <= 0.0 || stopPrice <= 0.0
              error("Price / StopPrice cannot be <= 0 for order type.")
          end
          order["price"] =  @sprintf("%.8f", price)
          order["stopPrice"] =  @sprintf("%.8f", stopPrice)
      end
  
      if orderType == "TAKE_PROFIT"
          if price <= 0.0 || stopPrice <= 0.0
              error("Price / StopPrice cannot be <= 0 for STOP_LOSS_LIMIT order type.")
          end
          order["price"] =  @sprintf("%.8f", price)
          order["stopPrice"] =  @sprintf("%.8f", stopPrice)
      end 
  
      if orderType == "LIMIT"  || orderType == "STOP_LOSS_LIMIT" || orderType == "TAKE_PROFIT_LIMIT"
          order["timeInForce"] = "GTC"
      end
  
      order
  end

# account call contains balances
function account(apiKey::String, apiSecret::String)
    headers = Dict("X-MBX-APIKEY" => apiKey)

    query = string("recvWindow=5000&timestamp=", timestamp())

    r = HTTP.request("GET", string(BINANCE_API_REST, "api/v3/account?", query, "&signature=", doSign(query, apiSecret)), headers)

    if r.status != 200
        println(r)
        return status
    end

    return r2j(r.body)
end

function executeOrder(order::Dict, apiKey, apiSecret; execute=false)
    headers = Dict("X-MBX-APIKEY" => apiKey)
    query = string(dict2Params(order), "&timestamp=", timestamp())
    body = string(query, "&signature=", doSign(query, apiSecret))
    println(body)

    uri = "api/v3/order/test"
    if execute
        uri = "api/v3/order"
    end

    r = HTTP.request("POST", string(BINANCE_API_REST, uri), headers, body)
    r2j(r.body)
end

# returns default balances with amounts > 0
function balances(apiKey::String, apiSecret::String; balanceFilter = x -> parse(Float64, x["free"]) > 0.0 || parse(Float64, x["locked"]) > 0.0)
    acc = account(apiKey,apiSecret)
    balances = filter(balanceFilter, acc["balances"])
end


# Websockets functions

function wsFunction(channel::Channel, ws::String, symbol::String)
    HTTP.WebSockets.open(string(BINANCE_API_WS, lowercase(symbol), ws); verbose=false) do io
      while !eof(io);
        put!(channel, r2j(readavailable(io)))
    end
  end
end

function wsTradeAgg(channel::Channel, symbol::String)
    wsFunction(channel, "@aggTrade", symbol)
end

function wsTradeRaw(channel::Channel, symbol::String)
    wsFunction(channel, "@trade", symbol)
end

function wsDepth(channel::Channel, symbol::String; level=5)
    wsFunction(channel, string("@depth", level), symbol)
end

function wsDepthDiff(channel::Channel, symbol::String)
    wsFunction(channel, "@depth", symbol)
end

function wsTicker(channel::Channel, symbol::String)
    wsFunction(channel, "@ticker", symbol)
end

function wsTicker24Hr(channel::Channel)
    HTTP.WebSockets.open(string(BINANCE_API_WS, "!ticker@arr"); verbose=false) do io
      while !eof(io);
        put!(channel, r2j(readavailable(io)))
    end
  end
end

function wsKline(channel::Channel, symbol::String; interval="1m")
  #interval => 1m 3m 5m 15m 30m 1h 2h 4h 6h 8h 12h 1d 3d 1w 1M
    wsFunction(channel, string("@kline_", interval), symbol)
end

function wsKlineStreams(channel::Channel, symbols::Array, interval="1m")
  #interval => 1m 3m 5m 15m 30m 1h 2h 4h 6h 8h 12h 1d 3d 1w 1M
    allStreams = map(s -> string(lowercase(s), "@kline_", interval), symbols)
    error = false;
    while !error
        try
            HTTP.WebSockets.open(string(BINANCE_API_WS,join(allStreams, "/")); verbose=false) do io
            while !eof(io);
                put!(channel, String(readavailable(io)))
            end
      end
        catch e
            println(e)
            error=true;
            println("error occured bailing wsklinestreams !")
        end
    end
end

function wsKlineStreams(callback::Function, symbols::Array, interval="1m")
    #interval => 1m 3m 5m 15m 30m 1h 2h 4h 6h 8h 12h 1d 3d 1w 1M
      allStreams = map(s -> string(lowercase(s), "@kline_", interval), symbols)
      error = false;
      while !error
          try
              HTTP.WebSockets.open(string(BINANCE_API_WS,join(allStreams, "/")); verbose=true) do io
              while !eof(io);
                wsData = String(readavailable(io))
                @async callback(wsData)
              end
        end
          catch e
              println(e)
              error=true;
              println("error occured bailing wsklinestreams !")
          end
      end
  end


function openUserData(apiKey)
    headers = Dict("X-MBX-APIKEY" => apiKey)
    r = HTTP.request("POST", BINANCE_API_USER_DATA_STREAM, headers)
    return r2j(r.body)["listenKey"]
end

function keepAlive(apiKey, listenKey)
    if length(listenKey) == 0
        return false
    end

    headers = Dict("X-MBX-APIKEY" => apiKey)
    body = string("listenKey=", listenKey) 
    r = HTTP.request("PUT", BINANCE_API_USER_DATA_STREAM, headers, body)
    return true
end

function closeUserData(apiKey, listenKey)
    if length(listenKey) == 0
        return false
    end
    headers = Dict("X-MBX-APIKEY" => apiKey)
    body = string("listenKey=", listenKey) 
    r = HTTP.request("DELETE", BINANCE_API_USER_DATA_STREAM, headers, body)
   return true
end

function wsUserData(channel::Channel, apiKey, listenKey; reconnect=true)

    function keepAlive()
        keepAlive(apiKey, listenKey)
    end    

    Timer(keepAlive, 1800; interval = 1800)

    error = false;
    while !error
        try
            HTTP.WebSockets.open(string(Binance.BINANCE_API_WS, listenKey); verbose=false) do io
                while !eof(io);
                    put!(channel, r2j(readavailable(io)))
                end
            end
        catch x
            println(x)
            error = true; 
        end
    end

    if reconnect
        wsUserData(channel, apikey, openUserData(apiKey))
    end

end

# helper
filterOnRegex(matcher, withDictArr; withKey="symbol") = filter(x -> match(Regex(matcher), x[withKey]) != nothing, withDictArr);

end
