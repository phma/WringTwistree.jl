module KeySchedule
using OffsetArrays
export mul65537,extendKey,keySchedule

function extendKey(str::Vector{UInt8})
  ret=OffsetArray(UInt16[],0:-1)
  len=length(str)
  if len>0
    n=(384+len-1)÷len
  else
    n=0
  end
  for i in 0:n-1
    for j in str
      push!(ret,256*i+j)
    end
  end
  ret
end

function mul65537(a::Integer,b::Integer)
  a64=convert(Int64,a)+1 # a and b are normally UInt16,
  b64=convert(Int64,b)+1 # which must be converted to avoid overflow.
  p=(a64*b64)%65537
  convert(typeof(a),p-1)
end

function alter!(subkey::OffsetArray{UInt16},keyWord::Integer,inx::Integer)
  subkey[inx]=mul65537(subkey[inx],keyWord)
  subkey[inx]+=subkey[(inx+59)%96]⊻subkey[(inx+36)%96]⊻subkey[(inx+62)%96]
  subkey[inx]=bitrotate(subkey[inx],8)
end

function keySchedule(key::Vector{UInt8})
  subkey=OffsetArray(UInt16[1],0:0)
  while length(subkey)<96
    push!(subkey,bitrotate(last(subkey)*0xd,8))
  end
  xkey=extendKey(key)
  for i in 0:length(xkey)-1
    alter!(subkey,xkey[i],i%96)
  end
  subkey
end

end
