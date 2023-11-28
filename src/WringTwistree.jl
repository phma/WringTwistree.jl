module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Permute.jl")
include("KeySchedule.jl")
using .Mix3,.RotBitcount,.Permute,.KeySchedule
export carmichael,mul65537,permute256
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.

end # module WringTwistree
