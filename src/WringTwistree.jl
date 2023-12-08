module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
include("Compress.jl")
include("Blockize.jl")
using OffsetArrays,Base.Threads
using .Mix3,.RotBitcount,.Sboxes,.Compress,.Blockize
export carmichael,findMaxOrder
export keyedWring,encryptSeq!,decryptSeq!,encryptPar!,decryptPar!,encrypt!,decrypt!
export keyedTwistree,initialize!
export sboxes,relPrimes,compress!,ℯ⁴_2adic,ℯ⁴_base2,blockize!,pad!
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
  for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcountSeq!(src,dst,1)
  for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecryptSeq(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  for i in eachindex(src)
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

mutable struct Twistree
  sbox		::OffsetArray{UInt8}
  tree2		::Vector{Vector{UInt8}}
  tree3		::Vector{Vector{UInt8}}
  partialBlock	::Vector{UInt8}
end

function keyedTwistree(key) # key is a String or Vector{UInt8}
  sbox=sboxes(key)
  tree2=Vector{UInt8}[]
  tree3=Vector{UInt8}[]
  partialBlock=UInt8[]
  Twistree(sbox,tree2,tree3,partialBlock)
end

function initialize!(tw::Twistree)
  # Check for valid S-box
  if size(tw.sbox)!=(256,3)
    error("wrong size S-box")
  end
  sum=0
  for i in 0:2
    for j in 0:255
      sum+=tw.sbox[j,i]
    end
  end
  if sum!=3*255*128
    error("invalid S-box")
  end
  # Check that the Twistree is empty
  if length(tw.tree2)>0 || length(tw.tree3)>0 || length(tw.partialBlock)>0
    error("call finalize before calling initialize again")
  end
  push!(tw.tree2,copy(ℯ⁴_2adic))
  push!(tw.tree3,copy(ℯ⁴_base2))
end

end # module WringTwistree
