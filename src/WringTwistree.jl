module WringTwistree
export mix3

function mix3(a::Integer,b::Integer,c::Integer)
  mask=(a|b|c)-(a&b&c)
  (a⊻mask,b⊻mask,c⊻mask)
end

end # module WringTwistree
