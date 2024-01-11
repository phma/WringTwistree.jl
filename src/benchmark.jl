
key96 = "Водворетраванатраведрова.Нерубидрованатраведвора!"
twistree96 = keyedTwistree(key96)
wring96 = keyedWring(key96)
text59049 = map(WringTwistree.xorn,collect(1:59049))

hash!(twistree96,text59049);

function xIntercept(lr::LinearRegression.LinearRegressor)
  -LinearRegression.bias(lr)/LinearRegression.slope(lr)[1]
end

function isReady(logRatios::Vector{<:Real})
  ready=true
  pos=false
  neg=false
  lim=0.05*√length(logRatios)
  for ratio in logRatios
    if abs(ratio)>lim
      ready=false
    end
    if ratio>0
      pos=true
    end
    if ratio<0
      neg=true
    end
  end
  pos && neg && ready
end

function oneThread(logRatios::Vector{<:Real})
  # If there's only one thread, all the logRatios are negative.
  pos=false
  neg=false
  for ratio in logRatios
    if ratio>0
      pos=true
    end
    if ratio<0
      neg=true
    end
  end
  !pos && neg
end

function twistreeTime(n::Integer) # in nanoseconds
  textn=map(WringTwistree.xorn,collect(1:n))
  trial=@benchmark hash!(twistree96,$textn)
  median(trial).time
end

function twistreeTimeRatio(n::Integer)
  textn=map(WringTwistree.xorn,collect(1:n))
  trialSeq=@benchmark hash!(twistree96,$textn,:sequential)
  trialPar=@benchmark hash!(twistree96,$textn,:parallel)
  median(trialSeq).time/median(trialPar).time
end

function twistreeBreakEven()
  lengths=Int[]
  logRatios=Float64[]
  i=0
  xint=-1.0
  lastXint=1e3
  last2Xint=1e6
  push!(lengths,256)
  push!(logRatios,log(twistreeTimeRatio(256)))
  println("Length=",lengths[1]," Ratio=",exp(logRatios[1]))
  push!(lengths,65536)
  push!(logRatios,log(twistreeTimeRatio(65536)))
  println("Length=",lengths[2]," Ratio=",exp(logRatios[2]))
  while (i<5 || abs(last(logRatios))>0.05 || !isReady(logRatios)) &&
	(i<3 || !oneThread(logRatios))
    lr=linregress(lengths,logRatios)
    last2Xint=lastXint
    lastXint=xint
    xint=xIntercept(lr)
    if xint<=0
      xint=lastXint*2/3
    end
    push!(lengths,round(Int,xint))
    push!(logRatios,log(twistreeTimeRatio(round(Int,xint))))
    if isodd(i)
      deleteat!(lengths,1)
      deleteat!(logRatios,1)
    end
    println("Length=",last(lengths)," Ratio=",exp(last(logRatios)))
    i+=1
  end
  if oneThread(logRatios)
    typemax(Int)
  else
    round(Int,xint)
  end
end

function wringTime(n::Integer) # in nanoseconds
  textn=map(WringTwistree.xorn,collect(1:n))
  trial=@benchmark encrypt!(wring96,$textn)
  median(trial).time
end

function wringTimeRatio(n::Integer)
  textn=map(WringTwistree.xorn,collect(1:n))
  trialSeq=@benchmark encrypt!(wring96,$textn,:sequential)
  trialPar=@benchmark decrypt!(wring96,$textn,:parallel)
  median(trialSeq).time/median(trialPar).time
end

function wringBreakEven()
  lengths=Int[]
  logRatios=Float64[]
  i=0
  xint=-1.0
  lastXint=1e3
  last2Xint=1e6
  push!(lengths,256)
  push!(logRatios,log(wringTimeRatio(256)))
  println("Length=",lengths[1]," Ratio=",exp(logRatios[1]))
  push!(lengths,65536)
  push!(logRatios,log(wringTimeRatio(65536)))
  println("Length=",lengths[2]," Ratio=",exp(logRatios[2]))
  while (i<5 || abs(last(logRatios))>0.05 || !isReady(logRatios)) &&
	(i<3 || !oneThread(logRatios))
    lr=linregress(lengths,logRatios)
    last2Xint=lastXint
    lastXint=xint
    xint=xIntercept(lr)
    if xint<=0
      xint=lastXint*2/3
    end
    push!(lengths,round(Int,xint))
    push!(logRatios,log(wringTimeRatio(round(Int,xint))))
    if isodd(i)
      deleteat!(lengths,1)
      deleteat!(logRatios,1)
    end
    println("Length=",last(lengths)," Ratio=",exp(last(logRatios)))
    i+=1
  end
  if oneThread(logRatios)
    typemax(Int)
  else
    round(Int,xint)
  end
end

"""
    setBreakEven()

Compute and set the break-even points for parallel Wring and Twistree.
Run this when upgrading Julia or installing on a new computer.
It takes several minutes.
"""
function setBreakEven()
  setBreakEven2(wringBreakEven(),twistreeBreakEven()÷32)
  @info("Restart Julia for the break-evens to take effect")
end
