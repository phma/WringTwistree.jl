module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
include("Compress.jl")
using OffsetArrays,Base.Threads
using .Mix3,.RotBitcount,.Sboxes,.Compress
export carmichael,findMaxOrder
export keyedWring,encryptSeq!,decryptSeq!,encryptPar!,decryptPar!,encrypt!,decrypt!
export blockSize,twistPrime,relPrimes,lfsr,backCrc!
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.
# findMaxOrder is needed for test.

const parBig::Int=1000

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

function roundEncryptSeq(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  mix3PartsSeq!(src,rprime) # this clobbers src
  @threads for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcountSeq!(src,dst,1)
  for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecryptSeq(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  @threads for i in eachindex(src)
    @inbounds src[i]-=xorn((i-1)⊻rond) # this clobbers src
  end
  rotBitcountSeq!(src,dst,-1)
  for i in eachindex(dst)
    @inbounds dst[i]=wring.invSbox[dst[i],(rond+i-1)%3]
  end
  mix3PartsSeq!(dst,rprime)
end

function roundEncryptPar(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  mix3PartsPar!(src,rprime) # this clobbers src
  @threads for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcountPar!(src,dst,1)
  @threads for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecryptPar(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  @threads for i in eachindex(src)
    @inbounds src[i]-=xorn((i-1)⊻rond) # this clobbers src
  end
  rotBitcountPar!(src,dst,-1)
  @threads for i in eachindex(dst)
    @inbounds dst[i]=wring.invSbox[dst[i],(rond+i-1)%3]
  end
  mix3PartsPar!(dst,rprime)
end

function encryptSeq!(wring::Wring,buf::Vector{UInt8})
# Puts ciphertext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in 0:nrond-1
    if (i&1)==0
      roundEncryptSeq(wring,buf,tmp,rprime,i)
    else
      roundEncryptSeq(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function decryptSeq!(wring::Wring,buf::Vector{UInt8})
# Puts plaintext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in reverse(0:nrond-1)
    if ((nrond-i)&1)==1
      roundDecryptSeq(wring,buf,tmp,rprime,i)
    else
      roundDecryptSeq(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function encryptPar!(wring::Wring,buf::Vector{UInt8})
# Puts ciphertext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in 0:nrond-1
    if (i&1)==0
      roundEncryptPar(wring,buf,tmp,rprime,i)
    else
      roundEncryptPar(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    @threads for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function decryptPar!(wring::Wring,buf::Vector{UInt8})
# Puts plaintext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in reverse(0:nrond-1)
    if ((nrond-i)&1)==1
      roundDecryptPar(wring,buf,tmp,rprime,i)
    else
      roundDecryptPar(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    @threads for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function encrypt!(wring::Wring,buf::Vector{UInt8})
  if length(buf)>parBig
    encryptPar!(wring,buf)
  else
    encryptSeq!(wring,buf)
  end
end

function decrypt!(wring::Wring,buf::Vector{UInt8})
  if length(buf)>parBig
    decryptPar!(wring,buf)
  else
    decryptSeq!(wring,buf)
  end
end

end # module WringTwistree
