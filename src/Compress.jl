module Compress
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export blockSize,twistPrime,relPrimes

const blockSize=32
const twistPrime=37

relPrimes=OffsetArray(map(findMaxOrder∘(x -> x÷3),collect(0x20:0x60)),0x20:0x60)

end
