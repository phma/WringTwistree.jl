module Mix3
export searchDir,mix3Parts!

function mix3(a::Integer,b::Integer,c::Integer)
  mask=(a|b|c)-(a&b&c)
  (a⊻mask,b⊻mask,c⊻mask)
end

function fiboPair(n::Integer)
  f0=0
  f1=1
  while f0<=n
    (f0,f1)=(f1,f1+f0)
  end
  (f0,f1)
end

function searchDir(n::Integer)
  (num,den)=fiboPair(n)
  (q,r)=divrem(n*num,den)
  if r*2<den
    (q,1)
  else
    (q+1,-1)
  end
end

function mix3Parts!(buf::Vector{<:Integer},rprime::Integer)
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

end
