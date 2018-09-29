include("/Users/drutje/development/julia/Binance.jl/src/Binance.jl")
using Binance

using Pkg;

# packages to install, first time can take a while downloading, please be patient ...
packages=["HTTP","JSON","Dates","DataFrames","Plots","StatPlots","PlotThemes","GR","PyPlot","PyCall","LaTeXStrings","Plotly","PlotlyJS"]

for package in packages
    if get(Pkg.installed(),package,-1) == -1
        println(" getting package : ", package)
        Pkg.add(package)
    end
end

userdataChannel = Channel(10)

apiKey = ""
apiSecret = ""

listenKey = Binance.openUserData(apiKey)
#Binance.closeUserData(apiKey)
listenKey = Binance.pingUserData(apiKey,listenKey)

wsUserData








