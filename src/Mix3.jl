module Mix3
using Primes,Mods,Base.Threads
export carmichael,findMaxOrder,mix3PartsSeq!,mix3PartsPar!

const yieldInterval=101

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

function carmichael(n::Integer)
  facs=factor(n)
  ret=one(n)
  for (p,ex) in facs
    if p==2 && ex>=3
      carfac=p^(ex-2)
    else
      carfac=p^(ex-1)*(p-1)
    end
    ret=lcm(ret,carfac)
  end
  ret
end

function isMaxOrder(modl::Integer,car::Integer,
		    fac::Primes.Factorization{<:Integer},n::Integer)
# modl is the modulus, car is its Carmichael function,
# fac is the factorization of car,
# and n is the number being tested.
# Returns true if n has maximum order, which implies it's a primitive root
# if modulus has any primitive roots.
  ret=Mod{modl}(n)^car==1
  for (p,ex) in fac
    ret=ret&&Mod{modl}(n)^(car÷p)!=1
  end
  ret
end

function findMaxOrder(n::Integer)
  car=carmichael(n)
  fac=factor(car)
  (start,dir)=searchDir(n)
  for i in 0:n
    if (i&1)==1
      m=start+i÷2+1
    else
      m=start-i÷2
    end
    if n==1 || isMaxOrder(n,car,fac,m)
      return m
    end
  end
  one(n)
end

function mix3Worker!(buf::Vector{<:Integer},a,b,c,aInc,cInc,len)
  while len>0 && a<b
    @inbounds (buf[a],buf[b],buf[c])=mix3(buf[a],buf[b],buf[c])
    a+=aInc
    b-=aInc
    c+=cInc
    if c>3*len
      c-=len
    end
    if a%yieldInterval==0
      yield()
    end
  end
end

function mix3PartsSeq!(buf::Vector{<:Integer},rprime::Integer)
  len=div(length(buf),3)
  a=1
  b=2*len
  c=2*len+1
  mix3Worker!(buf,a,b,c,1,rprime,len)
end

function mix3PartsPar!(buf::Vector{<:Integer},rprime::Integer)
  len=div(length(buf),3)
  a=1
  b=2*len
  c=2*len+1
  while len>0 && a<b
    @inbounds (buf[a],buf[b],buf[c])=mix3(buf[a],buf[b],buf[c])
    a+=1
    b-=1
    c+=rprime
    if c>3*len
      c-=len
    end
  end
end

end
