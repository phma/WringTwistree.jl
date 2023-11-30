module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
using .Mix3,.RotBitcount,.Sboxes
export carmichael,reschedule!,sboxes
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.

end # module WringTwistree
