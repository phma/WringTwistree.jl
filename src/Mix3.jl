module Mix3
using Primes,Mods,Base.Threads,OffsetArrays
export carmichael,findMaxOrder,relPrimes,mix3PartsSeq!,mix3PartsPar!

# This should be a prime greater than all prime factors of numbers of threads
# on CPUs. For instance, since there are 22-core 88-thread Power9 chips, it
# should be greater than 11.
const yieldInterval=8191

function mix3(a::Integer,b::Integer,c::Integer)
  mask=(a|b|c)-(a&b&c)
  (a⊻mask,b⊻mask,c⊻mask)
end

function fiboPair(n::Integer)
  f0=zero(n)
  f1=one(n)
  while f0<=n
    (f0,f1)=(f1,f1+f0)
  end
  (f0,f1)
end

function searchDir(n::Integer)
  (num,den)=fiboPair(BigInt(n))
  (q,r)=divrem(n*num,den)
  q=convert(typeof(n),q)
  if r*2<den
    (q,1)
  else
    (q+1,-1)
  end
end

"""
    carmichael(n::Integer)

Compute the Carmichael function, the largest multiplicative order of any number mod n.
"""
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
      m=start+dir*(i÷2+1)
    else
      m=start-dir*(i÷2)
    end
    if n==1 || isMaxOrder(n,car,fac,m)
      return convert(typeof(n),m)
    end
  end
  one(n)
end

const relPrimes=OffsetArray(map(findMaxOrder∘(x -> x÷0x3),
			    collect(0x0020:0x0060)),0x20:0x60)

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
  aInc=nthreads()
  cInc=(rprime*aInc)
  if len>0
    cInc%=len
  end
  tasks=Task[]
  for i in 1:aInc
    #println("Starting task a=",a," b=",b," c=",c," aInc=",aInc," cInc=",cInc)
    push!(tasks,@spawn mix3Worker!(buf,$a,$b,$c,aInc,cInc,len))
    a+=1
    b-=1
    c+=rprime
    if c>3*len
      c-=len
    end
  end
  for i in 1:aInc
    wait(tasks[i])
  end
end

end
