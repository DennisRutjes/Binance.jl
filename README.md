# Binance.jl
[Binance](https://www.binance.com/en?ref=35360148) (referral link) API with [Julialang](https://julialang.org/)

usage :

```julia
using Pkg;
Pkg.add(PackageSpec(url="https://github.com/DennisRutjes/Binance.jl",rev="master"))

packages=["Dates","DataFrames","Plots","GR"]

for package in packages
    if get(Pkg.installed(),package,-1) == -1
        println(" getting package : ", package)
        Pkg.add(package)
    end
end

# fill in correct values when using private binancecalls e.g. getBalances()
ENV["BINANCE_APIKEY"] = "REDACTED"; 
ENV["BINANCE_SECRET"] = "REDACTED";

using Binance,Dates, DataFrames, Plots

hr24 = Binance.get24HR()
hr24ETHBTC = Binance.get24HR("ETHBTC")

market = Binance.getMarket()
market_BNBBTC = Binance.getMarket("BNBBTC")

function getBinanceKlineDataframe(symbol; startDateTime = nothing, endDateTime = nothing, interval="1m")
    klines = Binance.getKlines(symbol; startDateTime = startDateTime, endDateTime = endDateTime, interval = interval)
    result = hcat(map(z -> map(x -> typeof(x) == String ? parse(Float64, x) : x, z), klines)...)';

    if size(result,2) == 0
        return nothing
    end

    symbolColumnData = map(x -> symbol, collect(1:size(result, 1)));
    df = DataFrame([symbolColumnData, Dates.unix2datetime.(result[:,1]/1000) ,result[:,2],result[:,3],result[:,4],result[:,5],result[:,6],result[:,8],Dates.unix2datetime.(result[:,7] / 1000),result[:,9],result[:,10],result[:,11]], [:symbol,:startDate,:open,:high,:low,:close,:volume,:quoteAVolume, :endDate, :trades, :tbBaseAVolume,:tbQuoteAVolume]);
end

dfKlines = getBinanceKlineDataframe("ETHBTC");

plot(dfKlines[:close])



```
