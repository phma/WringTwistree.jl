module Compress
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export blockSize,twistPrime,relPrimes

const blockSize=32
const twistPrime=37

relPrimes=OffsetArray(map(findMaxOrder∘(x -> x÷0x3),collect(0x0020:0x0060)),0x20:0x60)

end
