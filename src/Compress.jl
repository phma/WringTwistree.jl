module Compress
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export relPrimes,lfsr,backCrc!,compress!,blockSize,twistPrime

const blockSize=32
const twistPrime=37

const relPrimes=OffsetArray(map(findMaxOrder∘(x -> x÷0x3),
			    collect(0x0020:0x0060)),0x20:0x60)

function lfsr1(n::Integer)
  ((n&1)*0x84802140)⊻(n>>1)
end

const lfsr=OffsetArray(map(collect(0:255)) do x
  for i in 1:8
    x=lfsr1(x)
  end
  convert(UInt32,x)
end,0:255)

function backCrc!(src::Vector{<:Integer},dst::Vector{<:Integer})
  acc=0xdeadc0de
  @inbounds for i in reverse(eachindex(src))
    acc=(acc>>8)⊻lfsr[acc&255]⊻src[i]
    dst[i]=acc&255
  end
end

function roundCompress!(sbox::OffsetArray{UInt8},buf::Vector{UInt8},sboxalt::Integer)
  tmp=copy(buf)
  rprime=relPrimes[length(buf)]
  len=length(buf)÷3
  mix3PartsSeq!(buf,rprime);
  for i in eachindex(buf)
    @inbounds buf[i]=sbox[buf[i],(sboxalt+i-1)%3]
  end
  bc=rotBitcountSeq!(buf,tmp,twistPrime)
  backCrc!(tmp,buf)
  resize!(buf,length(buf)-4)
  bc # For cryptanalysis. The return value is ignored when hashing.
end

function compress!(sbox::OffsetArray{UInt8},buf::Vector{UInt8},sboxalt::Integer)
  while length(buf)>blockSize
    roundCompress!(sbox,buf,sboxalt)
  end
end

end
