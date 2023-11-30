module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using OffsetArrays
using .Mix3,.RotBitcount,.Sboxes
export carmichael,sboxes,inverse
export keyedWring
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.

struct Wring
  sbox    ::OffsetArray{UInt8}
  invSbox ::OffsetArray{UInt8}
end

function keyedWring(key) # key is a String or Vector{UInt8}
  sbox=sboxes(key)
  invSbox=inverse(sbox)
  Wring(sbox,invSbox)
end

end # module WringTwistree
