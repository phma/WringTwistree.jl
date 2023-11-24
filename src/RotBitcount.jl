module RotBitcount
export rotBitcount!

function rotBitcount!(src::Vector{UInt8},dst::Vector{UInt8},mult::Integer)
  len=length(src)
  if len!=length(dst)
    error("rotBitcount: size mismatch")
  end
  if src===dst
    error("rotBitcount: src and dst must be different")
  end
  multmod=mod(mult,len*8)
  bitcount=mapreduce(count_ones,+,src)
  rotcount=(bitcount*multmod)%(len*8)
  byte=rotcount>>3
  bit=rotcount&7
  for i in 1:length(dst)
    dst[i]=(src[(i+len-byte-1)%len+1]<<bit) | (src[(i+len-byte-2)%len+1]>>(8-bit))
  end
end

end
