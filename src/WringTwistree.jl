module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export carmichael,sboxes,inverse
export keyedWring,encrypt!,decrypt!
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

function xorn(n::Integer)
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
  mix3Parts!(src,rprime) # this clobbers src
  for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcount!(src,dst,1)
  for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecrypt(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  for i in eachindex(src)
    @inbounds src[i]-=xorn((i-1)⊻rond) # this clobbers src
  end
  rotBitcount!(src,dst,-1)
  for i in eachindex(dst)
    @inbounds dst[i]=wring.invSbox[dst[i],(rond+i-1)%3]
  end
  mix3Parts!(dst,rprime)
end

function encrypt!(wring::Wring,buf::Vector{UInt8})
# Puts ciphertext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in 0:nrond-1
    if (i&1)==0
      roundEncrypt(wring,buf,tmp,rprime,i)
    else
      roundEncrypt(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function decrypt!(wring::Wring,buf::Vector{UInt8})
# Puts plaintext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in reverse(0:nrond-1)
    if ((nrond-i)&1)==1
      roundDecrypt(wring,buf,tmp,rprime,i)
    else
      roundDecrypt(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

end # module WringTwistree
