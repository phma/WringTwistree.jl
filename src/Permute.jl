module Permute
using OffsetArrays
export permut8!,permut8x32!,dealInx

function permut8!(ys::OffsetArray{<:Any},off::Integer,n::Integer)
# off should be a multiple of 8.
# Permutes the eight elements starting at off according to n.
  swapOrder=[0,0,0,0,0,0,0]
  swapOrder[1]=n&1
  swapOrder[3]=(n>>1)&3
  swapOrder[7]=(n>>3)&7
  temp=((n>>6)&15)+1
  swapOrder[2]=temp%3
  swapOrder[5]=temp÷3
  temp=((n>>10)&31)+1
  if temp>16
    temp+=1
  end
  swapOrder[4]=temp%5
  swapOrder[6]=temp÷5
  for i in 1:7
    ys[off+i],ys[off+swapOrder[i]]=ys[off+swapOrder[i]],ys[off+i]
  end
end

function permut8x32!(sbox::OffsetArray{<:Any},key::OffsetArray{<:Integer})
  @assert length(sbox)==8*length(key)
  for i in 0:length(key)-1
    permut8!(sbox,8*i,key[i])
  end
end

const shift3=OffsetArray([0x00,0x1d,0x3a,0x27,0x74,0x69,0x4e,0x53],0:7)

function dealInx(n::Integer)
  ((n<<3)&0xf8)⊻(shift3[(n>>5)&7])
end

end
