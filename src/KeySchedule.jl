module KeySchedule
using OffsetArrays
export mul65537

function mul65537(a::Integer,b::Integer)
  a64=convert(Int64,a)+1 # a and b are normally UInt16,
  b64=convert(Int64,b)+1 # which must be converted to avoid overflow.
  p=(a64*b64)%65537
  convert(typeof(a),p-1)
end

end
