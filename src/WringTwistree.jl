module WringTwistree
export mix3,mix3Parts!

function mix3(a::Integer,b::Integer,c::Integer)
  mask=(a|b|c)-(a&b&c)
  (a⊻mask,b⊻mask,c⊻mask)
end

function mix3Parts!(buf::Vector{UInt8},rprime::Integer)
  len=div(length(buf),3)
  a=1
  b=2*len
  c=2*len+1
  while len>0 && a<b
    (buf[a],buf[b],buf[c])=mix3(buf[a],buf[b],buf[c])
    a+=1
    b-=1
    c+=rprime
    if c>3*len
      c-=len
    end
  end
end

end # module WringTwistree
