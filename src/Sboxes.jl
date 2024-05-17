module Sboxes
include("Permute.jl")
include("KeySchedule.jl")
using OffsetArrays
using .KeySchedule,.Permute
export sboxes,linearSbox,linearInvSbox,inverse,Яхид

struct Яхид # Hebrew יחיד (singleton) transliterated to Cyrillic
end	    # so that it can be capitalized

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

function linearSbox()
  sbox=OffsetArray(zeros(UInt8,256,3),0:255,0:2)
  for i=0:2
    for j=0:255
      sbox[j,i]=bitrotate(UInt8(j),3*i+1)
    end
  end
  sbox
end

function linearInvSbox()
  sbox=OffsetArray(zeros(UInt8,256,3),0:255,0:2)
  for i=0:2
    for j=0:255
      sbox[j,i]=bitrotate(UInt8(j),7-3*i)
    end
  end
  sbox
end

function sboxes(key::String)
  sboxes(Vector{UInt8}(key))
end

function inverse(sbox::OffsetArray{UInt8})
  inv=copy(sbox)
  for i=0:2
    for j=0:255
      inv[sbox[j,i],i]=j
    end
  end
  inv
end

end
