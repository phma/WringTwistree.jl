module KeySchedule
using OffsetArrays
export mul65537,extendKey

function extendKey(str::Vector{UInt8})
  ret=UInt16[]
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

end
