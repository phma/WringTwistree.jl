module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
include("Compress.jl")
include("Blockize.jl")
using OffsetArrays,Base.Threads
using .Mix3,.RotBitcount,.Sboxes,.Compress,.Blockize
export carmichael,findMaxOrder
export keyedWring,encryptSeq!,decryptSeq!,encryptPar!,decryptPar!,encrypt!,decrypt!
export keyedTwistree,initialize!,update!,finalize!
export sboxes,relPrimes,compress!,ℯ⁴_2adic,ℯ⁴_base2,blockize!,pad!
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.
# findMaxOrder is needed for test.

const parBig::Int=1000

function nRounds(len::Integer)
  ret=3
  while len>=3
    len÷=3
    ret+=1
  end
  ret
end

function xorn(n::Integer)
  ret=0x00
  while n>0
    ret⊻=UInt8(n&0xff)
    n>>=8
  end
  ret
end

struct Wring
  sbox    ::OffsetArray{UInt8}
  invSbox ::OffsetArray{UInt8}
end

function keyedWring(key) # key is a String or Vector{UInt8}
  sbox=sboxes(key)
  invSbox=inverse(sbox)
  Wring(sbox,invSbox)
end

function roundEncryptSeq(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  mix3PartsSeq!(src,rprime) # this clobbers src
  for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcountSeq!(src,dst,1)
  for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecryptSeq(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  for i in eachindex(src)
    @inbounds src[i]-=xorn((i-1)⊻rond) # this clobbers src
  end
  rotBitcountSeq!(src,dst,-1)
  for i in eachindex(dst)
    @inbounds dst[i]=wring.invSbox[dst[i],(rond+i-1)%3]
  end
  mix3PartsSeq!(dst,rprime)
end

function roundEncryptPar(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  mix3PartsPar!(src,rprime) # this clobbers src
  @threads for i in eachindex(src)
    @inbounds src[i]=wring.sbox[src[i],(rond+i-1)%3]
  end
  rotBitcountPar!(src,dst,1)
  @threads for i in eachindex(dst)
    @inbounds dst[i]+=xorn((i-1)⊻rond)
  end
end

function roundDecryptPar(wring::Wring,src::Vector{UInt8},dst::Vector{UInt8},
		      rprime::Integer,rond::Integer)
  @threads for i in eachindex(src)
    @inbounds src[i]-=xorn((i-1)⊻rond) # this clobbers src
  end
  rotBitcountPar!(src,dst,-1)
  @threads for i in eachindex(dst)
    @inbounds dst[i]=wring.invSbox[dst[i],(rond+i-1)%3]
  end
  mix3PartsPar!(dst,rprime)
end

function encryptSeq!(wring::Wring,buf::Vector{UInt8})
# Puts ciphertext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in 0:nrond-1
    if (i&1)==0
      roundEncryptSeq(wring,buf,tmp,rprime,i)
    else
      roundEncryptSeq(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function decryptSeq!(wring::Wring,buf::Vector{UInt8})
# Puts plaintext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in reverse(0:nrond-1)
    if ((nrond-i)&1)==1
      roundDecryptSeq(wring,buf,tmp,rprime,i)
    else
      roundDecryptSeq(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function encryptPar!(wring::Wring,buf::Vector{UInt8})
# Puts ciphertext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in 0:nrond-1
    if (i&1)==0
      roundEncryptPar(wring,buf,tmp,rprime,i)
    else
      roundEncryptPar(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    @threads for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function decryptPar!(wring::Wring,buf::Vector{UInt8})
# Puts plaintext back into buf.
  tmp=copy(buf)
  nrond=nRounds(length(buf))
  rprime=length(buf)<3 ? 1 : findMaxOrder(length(buf)÷3)
  for i in reverse(0:nrond-1)
    if ((nrond-i)&1)==1
      roundDecryptPar(wring,buf,tmp,rprime,i)
    else
      roundDecryptPar(wring,tmp,buf,rprime,i)
    end
  end
  if (nrond&1)>0
    @threads for i in eachindex(tmp)
      @inbounds buf[i]=tmp[i]
    end
  end
end

function encrypt!(wring::Wring,buf::Vector{UInt8})
  if length(buf)>parBig
    encryptPar!(wring,buf)
  else
    encryptSeq!(wring,buf)
  end
end

function decrypt!(wring::Wring,buf::Vector{UInt8})
  if length(buf)>parBig
    decryptPar!(wring,buf)
  else
    decryptSeq!(wring,buf)
  end
end

mutable struct Twistree
  sbox		::OffsetArray{UInt8}
  tree2		::Vector{Vector{UInt8}}
  tree3		::Vector{Vector{UInt8}}
  partialBlock	::Vector{UInt8}
end

function keyedTwistree(key) # key is a String or Vector{UInt8}
  sbox=sboxes(key)
  tree2=Vector{UInt8}[]
  tree3=Vector{UInt8}[]
  partialBlock=UInt8[]
  Twistree(sbox,tree2,tree3,partialBlock)
end

function initialize!(tw::Twistree)
  # Check for valid S-box
  if size(tw.sbox)!=(256,3)
    error("wrong size S-box")
  end
  sum=0
  for i in 0:2
    for j in 0:255
      sum+=tw.sbox[j,i]
    end
  end
  if sum!=3*255*128
    error("invalid S-box")
  end
  # Check that the Twistree is empty
  if length(tw.tree2)>0 || length(tw.tree3)>0 || length(tw.partialBlock)>0
    error("call finalize before calling initialize again")
  end
  push!(tw.tree2,copy(ℯ⁴_2adic))
  push!(tw.tree3,copy(ℯ⁴_base2))
end

function compressPairs!(tw::Twistree)
  i=1
  while length(tw.tree2[i])>blockSize
    if i==length(tw.tree2)
      push!(tw.tree2,UInt8[])
    end
    compress!(tw.sbox,tw.tree2[i],0)
    append!(tw.tree2[i+1],tw.tree2[i])
    empty!(tw.tree2[i])
    i+=1
  end
end

function compressTriples!(tw::Twistree)
  i=1
  while length(tw.tree3[i])>2*blockSize
    if i==length(tw.tree3)
      push!(tw.tree3,UInt8[])
    end
    compress!(tw.sbox,tw.tree3[i],1)
    append!(tw.tree3[i+1],tw.tree3[i])
    empty!(tw.tree3[i])
    i+=1
  end
end

function compressPairs256!(tw::Twistree)
  i=9
  while length(tw.tree2[i])>blockSize
    if i==length(tw.tree2)
      push!(tw.tree2,UInt8[])
    end
    compress!(tw.sbox,tw.tree2[i],0)
    append!(tw.tree2[i+1],tw.tree2[i])
    empty!(tw.tree2[i])
    i+=1
  end
end

function compressTriples243!(tw::Twistree)
  i=6
  while length(tw.tree3[i])>2*blockSize
    if i==length(tw.tree3)
      push!(tw.tree3,UInt8[])
    end
    compress!(tw.sbox,tw.tree3[i],1)
    append!(tw.tree3[i+1],tw.tree3[i])
    empty!(tw.tree3[i])
    i+=1
  end
end

function compress256Blocks(tw::Twistree,blocks::Vector{Vector{UInt8}},start::Integer)
  l1=l2=l3=l4=l5=l6=l7=l8=Vector{UInt8}[]
  for i in 0:127
    push!(l1,copy(blocks[start+2*i]))
    append!(l1[i+1],blocks[start+2*i+1])
    compress!(tw.sbox,l1[i+1],0)
  end
  for i in 0:63
    push!(l2,l1[2*i+1])
    append!(l2[i+1],l1[2*i+2])
    compress!(tw.sbox,l2[i+1],0)
  end
  for i in 0:31
    push!(l3,l2[2*i+1])
    append!(l3[i+1],l2[2*i+2])
    compress!(tw.sbox,l3[i+1],0)
  end
  for i in 0:15
    push!(l4,l3[2*i+1])
    append!(l4[i+1],l3[2*i+2])
    compress!(tw.sbox,l4[i+1],0)
  end
  for i in 0:7
    push!(l5,l4[2*i+1])
    append!(l5[i+1],l4[2*i+2])
    compress!(tw.sbox,l5[i+1],0)
  end
  for i in 0:3
    push!(l6,l5[2*i+1])
    append!(l6[i+1],l5[2*i+2])
    compress!(tw.sbox,l6[i+1],0)
  end
  for i in 0:1
    push!(l7,l6[2*i+1])
    append!(l7[i+1],l6[2*i+2])
    compress!(tw.sbox,l7[i+1],0)
  end
  push!(l8,l7[1])
  append!(l8[1],l7[2])
  compress!(tw.sbox,l8[1],0)
  l8[1]
end

function compress243Blocks(tw::Twistree,blocks::Vector{Vector{UInt8}},start::Integer)
  l1=l2=l3=l4=l5=Vector{UInt8}[]
  for i in 0:80
    push!(l1,copy(blocks[start+3*i]))
    append!(l1[i+1],blocks[start+3*i+1])
    append!(l1[i+1],blocks[start+3*i+2])
    compress!(tw.sbox,l1[i+1],1)
  end
  for i in 0:26
    push!(l2,l1[3*i+1])
    append!(l2[i+1],l1[3*i+2])
    append!(l2[i+1],l1[3*i+3])
    compress!(tw.sbox,l2[i+1],1)
  end
  for i in 0:8
    push!(l3,l2[3*i+1])
    append!(l3[i+1],l2[3*i+2])
    append!(l3[i+1],l2[3*i+3])
    compress!(tw.sbox,l3[i+1],1)
  end
  for i in 0:2
    push!(l4,l3[3*i+1])
    append!(l4[i+1],l3[3*i+2])
    append!(l4[i+1],l3[3*i+3])
    compress!(tw.sbox,l4[i+1],1)
  end
  push!(l5,l4[1])
  append!(l5[1],l4[2])
  append!(l5[1],l4[3])
  compress!(tw.sbox,l5[1],1)
  l5[1]
end

function finalizePairs!(tw::Twistree)
  for i in eachindex(tw.tree2)
    compress!(tw.sbox,tw.tree2[i],0)
    if i<length(tw.tree2)
      append!(tw.tree2[i+1],tw.tree2[i])
      empty!(tw.tree2[i])
    end
  end
end

function finalizeTriples!(tw::Twistree)
  for i in eachindex(tw.tree3)
    compress!(tw.sbox,tw.tree3[i],1)
    if i<length(tw.tree3)
      append!(tw.tree3[i+1],tw.tree3[i])
      empty!(tw.tree3[i])
    end
  end
end

function updateSeq!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  for i in eachindex(blocks)
    append!(tw.tree2[1],blocks[i])
    compressPairs!(tw)
    append!(tw.tree3[1],blocks[i])
    compressTriples!(tw)
  end
end

function update2!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  head=0
  len=length(blocks)
  for i in reverse(1:8)
    if i<=length(tw.tree2)
      head=2*head+length(tw.tree2[i])÷blockSize
    end
  end # the number of blocks already pushed into tree2 mod 256
  println("head=",head)
  if head>0
    head=256-head
  end # the number of more blocks to push to get a multiple of 256
  if head>len
    head=len
  end
  body=(len-head)÷256
  if body<0
    body=0
  end
  tail=head+256*body
  println("head=",head," body=",body," tail=",tail)
  for i in 1:head
    append!(tw.tree2[1],blocks[i])
    compressPairs!(tw)
  end
  bodyHash=OffsetArray(Vector{UInt8}[],0:-1)
  for i in 0:body-1
    push!(bodyHash,UInt8[])
  end
  for i in 0:body-1
    bodyHash[i]=compress256Blocks(tw,blocks,head+1+256*i)
  end
  for i in 0:body-1
    append!(tw.tree2[9],bodyHash[i])
    compressPairs256!(tw)
  end
  for i in tail+1:len
    append!(tw.tree2[1],blocks[i])
    compressPairs!(tw)
  end
end

function update3!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  head=0
  len=length(blocks)
  for i in reverse(1:5)
    if i<=length(tw.tree3)
      head=3*head+length(tw.tree2[i])÷blockSize
    end
  end # the number of blocks already pushed into tree3 mod 243
  if head>len
    head=len
  end
  if head>0
    head=243-head
  end # the number of more blocks to push to get a multiple of 243
  body=(len-head)÷243
  if body<0
    body=0
  end
  tail=head+243*body
  for i in 1:head
    append!(tw.tree3[1],blocks[i])
    compressTriples!(tw)
  end
  for i in 0:body-1
    for j in (head+1+243*i):(head+243*(i+1))
      append!(tw.tree3[1],blocks[j])
      compressTriples!(tw)
    end
  end
  for i in tail+1:len
    append!(tw.tree3[1],blocks[i])
    compressTriples!(tw)
  end
end

function updatePar!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  tasks=Task[]
  push!(tasks,@spawn update2!(tw,blocks))
  push!(tasks,@spawn update3!(tw,blocks))
  for i in 1:2
    wait(tasks[i])
  end
end

function updateParSeq!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  update2!(tw,blocks)
  update3!(tw,blocks)
end

function update!(tw::Twistree,data::Vector{UInt8})
  # Check that the Twistree has been initialized
  if length(tw.tree2)==0 || length(tw.tree3)==0
    error("call initialize before update")
  end
  blocks=blockize!(data,tw.partialBlock)
  updateParSeq!(tw,blocks)
end

function finalize!(tw::Twistree)
  # Check that the Twistree has been initialized
  if length(tw.tree2)==0 || length(tw.tree3)==0
    error("call initialize before update")
  end
  lastBlock=pad!(tw.partialBlock)
  append!(tw.tree2[1],lastBlock)
  compressPairs!(tw)
  finalizePairs!(tw)
  append!(tw.tree3[1],lastBlock)
  compressTriples!(tw)
  finalizeTriples!(tw)
  fruit=copy(last(tw.tree2))
  append!(fruit,last(tw.tree3))
  compress!(tw.sbox,fruit,2)
  empty!(tw.tree2)
  empty!(tw.tree3)
  fruit
end

end # module WringTwistree
