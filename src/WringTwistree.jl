module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export carmichael,sboxes,inverse
export keyedWring,nRounds,xorn
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.

function nRounds(len::Integer)
  ret=3
  while len>=3
    len÷=3
    ret+=1
  end
  ret
end

function xorn(n::Unsigned)
  ret=0x00
  while n>0
    ret⊻=UInt8(n&0xff)
    n>>=8
  end
  ret
end

struct Wring
  sbox    ::OffsetArray{UInt8}
  invSbox ::OffsetArray{UInt8}
end

function keyedWring(key) # key is a String or Vector{UInt8}
  sbox=sboxes(key)
  invSbox=inverse(sbox)
  Wring(sbox,invSbox)
end

function roundEncrypt(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  mix3parts!(src,rprime) # this clobbers src
  for i in eachindex(src)
    src[i]=wring.sbox[src[i],(rond+i)%3]
  end
  rotBitcount(src,dst,1)
  for i in eachindex(dst)
    dst[i]+=xorn(i⊻rond)
  end
end

end # module WringTwistree
