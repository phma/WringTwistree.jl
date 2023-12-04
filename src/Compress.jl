module Compress
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export blockSize,twistPrime

const blockSize=32
const twistPrime=37

end
