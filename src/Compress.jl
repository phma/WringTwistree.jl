module Compress
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export blockSize,twistPrime,relPrimes,lfsr,backCrc!

const blockSize=32
const twistPrime=37

relPrimes=OffsetArray(map(findMaxOrder∘(x -> x÷0x3),collect(0x0020:0x0060)),0x20:0x60)

function lfsr1(n::Integer)
  ((n&1)*0x84802140)⊻(n>>1)
end

lfsr=OffsetArray(map(collect(0:255)) do x
  for i in 1:8
    x=lfsr1(x)
  end
  convert(UInt32,x)
end,0:255)

function backCrc!(src::Vector{<:Integer},dst::Vector{<:Integer})
  acc=0xdeadc0de
  for i in reverse(eachindex(src))
    acc=(acc>>8)⊻lfsr[acc&255]⊻src[i]
    dst[i]=acc&255
  end
end

end
