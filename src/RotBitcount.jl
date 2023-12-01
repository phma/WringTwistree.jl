module RotBitcount
export rotBitcount!

# This module is used in both Wring and Twistree.
# It rotates an array of bytes by a multiple of its bitcount,
# producing another array of the same size. As long as the multiplier
# is relatively prime to the number of bits in the array, this
# operation satisfies the strict avalanche criterion. Changing *two*
# bits, however, has half a chance of changing only two bits in
# the output.

function rotBitcount!(src::Vector{UInt8},dst::Vector{UInt8},mult::Integer)
  len=length(src)
  @assert len==length(dst) "rotBitcount: size mismatch"
  @assert src!==dst "rotBitcount: src and dst must be different"
  multmod=mod(mult,len*8)
  @inbounds bitcount=mapreduce(count_ones,+,src)
  rotcount=(bitcount*multmod)%(len*8)
  byte=rotcount>>3
  bit=rotcount&7
  for i in 1:len
    @inbounds dst[i]=(src[(i+len-byte-1)%len+1]<<bit) | (src[(i+len-byte-2)%len+1]>>(8-bit))
  end
end

end
