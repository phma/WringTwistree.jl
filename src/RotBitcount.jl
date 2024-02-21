module RotBitcount
using Base.Threads,OffsetArrays
export rotBitcountSeq!,rotBitcountPar!,cycleRotBitcount

# This module is used in both Wring and Twistree.
# It rotates an array of bytes by a multiple of its bitcount,
# producing another array of the same size. As long as the multiplier
# is relatively prime to the number of bits in the array, this
# operation satisfies the strict avalanche criterion. Changing *two*
# bits, however, has half a chance of changing only two bits in
# the output.

function rotBitcountSeq!(src::Vector{UInt8},dst::Vector{UInt8},mult::Integer)
  len=length(src)
  @assert len==length(dst) "rotBitcount: size mismatch"
  @assert src!==dst "rotBitcount: src and dst must be different"
  if len>0
    multmod=mod(mult,len*8)
  else
    multmod=mult
  end
  @inbounds bitcount=mapreduce(count_ones,+,src,init=0)
  if len>0
    rotcount=(bitcount*multmod)%(len*8)
  else
    rotcount=bitcount*multmod
  end
  byte=rotcount>>3
  bit=rotcount&7
  for i in 1:byte
    @inbounds dst[i]=(src[i+len-byte]<<bit) | (src[i+len-byte-1]>>(8-bit))
  end
  @inbounds dst[byte+1]=(src[1]<<bit) | (src[len]>>(8-bit))
  for i in byte+2:len
    @inbounds dst[i]=(src[i-byte]<<bit) | (src[i-byte-1]>>(8-bit))
  end
  bitcount
end

function rotBitcountPar!(src::Vector{UInt8},dst::Vector{UInt8},mult::Integer)
  len=length(src)
  @assert len==length(dst) "rotBitcount: size mismatch"
  @assert src!==dst "rotBitcount: src and dst must be different"
  if len>0
    multmod=mod(mult,len*8)
  else
    multmod=mult
  end
  @inbounds bitcount=mapreduce(count_ones,+,src,init=0)
  if len>0
    rotcount=(bitcount*multmod)%(len*8)
  else
    rotcount=bitcount*multmod
  end
  byte=rotcount>>3
  bit=rotcount&7
  # The alternative to using % is to do two loops, as above, but when parallel,
  # stopping and starting the threads in the middle takes more time than mods.
  @threads for i in 1:len
    @inbounds dst[i]=(src[(i+len-byte-1)%len+1]<<bit) |
		     (src[(i+len-byte-2)%len+1]>>(8-bit))
  end
  bitcount
end

"""
    cycleRotBitcount(buf::Vector{UInt8})

Repeatedly runs rotBitcount on buf until it repeats. The return value is (a,b),
where a-b is the cycle length. If b>0, there's a bug.
"""
function cycleRotBitcount(buf::Vector{UInt8})
  history=OffsetArray([buf],0:0)
  cycle=(-1,-1)
  while cycle[1]<0
    for i in 0:length(history)-2
      if history[i]==last(history)
	cycle=(length(history)-1,i)
      end
    end
    push!(history,copy(last(history)))
    rotBitcountSeq!(history[length(history)-2],last(history),1)
  end
  cycle
end

end
