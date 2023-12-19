
key96 = "Водворетраванатраведрова.Нерубидрованатраведвора!"
twistree96 = keyedTwistree(key96)
text59049 = map(WringTwistree.xorn,collect(1:59049))

hash!(twistree96,text59049);

function twistreeTimeRatio(n::Integer)
  textn=map(WringTwistree.xorn,collect(1:n))
  trialSeq=@benchmark hash!(twistree96,$textn,:sequential)
  trialPar=@benchmark hash!(twistree96,$textn,:parallel)
  median(trialSeq).time/median(trialPar).time
end

function twistreeBreakEven()
  minLength=1
  minRatio=twistreeTimeRatio(minLength) # <1
  maxLength=100000
  maxRatio=twistreeTimeRatio(maxLength) # >1
  midLength=0
  while maxLength-minLength>1
    midLength=(minLength+maxLength)÷2
    midRatio=twistreeTimeRatio(midLength)
    println("Length=",midLength," Ratio=",midRatio)
    if midRatio>1
      maxLength=midLength
      maxRatio=midRatio
    else
      minLength=midLength
      minRatio=midRatio
    end
  end
  midLength
end
