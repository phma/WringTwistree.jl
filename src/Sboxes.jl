module Sboxes
include("Permute.jl")
include("KeySchedule.jl")
using OffsetArrays
using .KeySchedule,.Permute
export sboxes

function sboxes(key::Vector{UInt8})
  sbox=OffsetArray(zeros(UInt8,256,3),0:255,0:2)
  subkey=keySchedule(key)
  sbox[:,0]=permute256(subkey)
  reschedule!(subkey)
  sbox[:,1]=permute256(subkey)
  reschedule!(subkey)
  sbox[:,2]=permute256(subkey)
  sbox
end

end
