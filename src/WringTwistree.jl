module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Permute.jl")
using .Mix3,.RotBitcount,.Permute
export carmichael,permut8!
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.

end # module WringTwistree
