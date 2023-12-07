module Blockize
include("Compress.jl")
using OffsetArrays
using .Compress
export ℯ⁴_2adic,ℯ⁴_base2,blockize!,pad!

# ℯ⁴, in two binary representations, is prepended to the
# blocks being hashed, so that if the message is only one block,
# two different compressed blocks are combined at the end.

const ℯ⁴_2adic=
  [ 0x4d, 0x41, 0x8e, 0x38, 0x72, 0x1a, 0x3a, 0xeb
  , 0x18, 0xe0, 0x08, 0x7f, 0xa3, 0x7f, 0x9c, 0xe0
  , 0x17, 0xb6, 0x45, 0xee, 0xa5, 0x3c, 0x95, 0x34
  , 0xca, 0x6d, 0x5c, 0xfe, 0x7f, 0x94, 0x14, 0x09
  ]

const ℯ⁴_base2=
  [ 0xe8, 0xa7, 0x66, 0xce, 0x5b, 0x2e, 0x8a, 0x39
  , 0x4b, 0xb7, 0x89, 0x2e, 0x0c, 0xd5, 0x94, 0x05
  , 0xda, 0x72, 0x7b, 0x72, 0xfb, 0x77, 0xda, 0x1a
  , 0xcf, 0xb0, 0x74, 0x4e, 0x5c, 0x20, 0x99, 0x36
  ]

function blockize!(bs::Vector{UInt8},part::Vector{UInt8})
  ret=Vector{UInt8}[]
  i=0
  if length(part)+length(bs)>=blockSize
    i=blockSize-length(part);
    append!(part,bs[1:i])
    push!(ret,copy(part))
    empty!(part)
  end
  while length(bs)-i>=blockSize
    append!(part,bs[i+1:i+blockSize])
    push!(ret,copy(part))
    empty!(part)
    i+=blockSize
  end
  append!(part,bs[i+1:length(bs)])
  ret
end

function pad!(part::Vector{UInt8})
  ret=UInt8[]
  for i in 1:blockSize-length(part)
    push!(part,i-1)
  end
  ret=copy(part)
  empty!(part)
  ret
end

end
