module WringTwistree
include("Mix3.jl")
include("RotBitcount.jl")
include("Sboxes.jl")
include("Compress.jl")
include("Blockize.jl")
using OffsetArrays,Base.Threads,BenchmarkTools,Preferences,LinearRegression
using .Mix3,.RotBitcount,.Sboxes,.Compress,.Blockize
export carmichael
export keyedWring,encryptSeq!,decryptSeq!,encryptPar!,decryptPar!,encrypt!,decrypt!
export keyedTwistree,initialize!,update!,finalize!,hash!,cycleRotBitcount
export setBreakEven # in benchmark
# carmichael is exported in case someone wants the Carmichael function,
# which I couldn't find.
# findMaxOrder is needed for test.

#--------------------------------------------------------------
# Wring is a whole-message cipher.

const parBreakEvenWring::Int=@load_preference("parBreakEvenWring",typemax(Int))
const parBreakEvenTwistree::Int=@load_preference("parBreakEvenTwistree",typemax(Int))

function setBreakEven2(beWring::Int,beTwistree::Int)
  @set_preferences!("parBreakEvenWring"=>beWring)
  @set_preferences!("parBreakEvenTwistree"=>beTwistree)
end

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

"""
    keyedWring(key)

Create a Wring which can be used to encrypt or decrypt a Vector{UInt8}.
The key can be a String or Vector{UInt8} and should be at longest 96 bytes.

# Examples

```julia-repl
julia> wring=keyedWring("aoeu")
WringTwistree.Wring(UInt8[0x99 0x5e 0xc9; 0xd6 0xf9 0x17; … ;
0x28 0xc8 0x32; 0xb0 0x81 0x99], UInt8[0x74 0x43 0x06; 0xb8 0x92 0xb6; … ;
0xca 0x3d 0xc5; 0x1d 0x11 0xbc])

julia> wring0=keyedWring("")
WringTwistree.Wring(UInt8[0x59 0xe9 0xe7; 0xdb 0x13 0x00; … ;
0xfc 0x76 0x38; 0x27 0x55 0xfd], UInt8[0x66 0x5c 0x01; 0x49 0x4c 0xba; … ;
0xe9 0x3a 0x73; 0xbd 0x45 0x08])
```
"""
function keyedWring(key)
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

function encrypt!(wring::Wring,buf::Vector{UInt8},parseq::Symbol=:default)
  if parseq==:default
    if length(buf)>=parBreakEvenWring
      parseq=:parallel
    else
      parseq=:sequential
    end
  end
  if parseq==:parallel
    encryptPar!(wring,buf)
  else
    encryptSeq!(wring,buf)
  end
end

function decrypt!(wring::Wring,buf::Vector{UInt8},parseq::Symbol=:default)
  if parseq==:default
    if length(buf)>parBreakEvenWring
      parseq=:parallel
    else
      parseq=:sequential
    end
  end
  if parseq==:parallel
    decryptPar!(wring,buf)
  else
    decryptSeq!(wring,buf)
  end
end

#--------------------------------------------------------------
# Twistree is a hash function.

mutable struct Twistree
  sbox		::OffsetArray{UInt8}
  tree2		::Vector{Vector{UInt8}}
  tree3		::Vector{Vector{UInt8}}
  partialBlock	::Vector{UInt8}
end

"""
    keyedTwistree(key)

Create a Twistree which can be used to hash a Vector{UInt8}.
The key can be a String or Vector{UInt8} and should be at longest 96 bytes.
For an unkeyed hash, use an empty string.

# Examples

```julia-repl
julia> tw=keyedTwistree("aoeu")
WringTwistree.Twistree(UInt8[0x99 0x5e 0xc9; 0xd6 0xf9 0x17; … ;
0x28 0xc8 0x32; 0xb0 0x81 0x99], Vector{UInt8}[], Vector{UInt8}[], UInt8[])

julia> tw0=keyedTwistree("")
WringTwistree.Twistree(UInt8[0x59 0xe9 0xe7; 0xdb 0x13 0x00; … ;
0xfc 0x76 0x38; 0x27 0x55 0xfd], Vector{UInt8}[], Vector{UInt8}[], UInt8[])
```
"""
function keyedTwistree(key)
  sbox=sboxes(key)
  tree2=Vector{UInt8}[]
  tree3=Vector{UInt8}[]
  partialBlock=UInt8[]
  Twistree(sbox,tree2,tree3,partialBlock)
end

"""
    initialize!(tw::Twistree)

Initialize a Twistree. Do this before calling `update!` and `finalize!`.
"""
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
  return nothing
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
  l1=Vector{Vector{UInt8}}(undef,128)
  l2=Vector{Vector{UInt8}}(undef,64)
  l3=Vector{Vector{UInt8}}(undef,32)
  l4=Vector{Vector{UInt8}}(undef,16)
  l5=Vector{Vector{UInt8}}(undef,8)
  l6=Vector{Vector{UInt8}}(undef,4)
  l7=Vector{Vector{UInt8}}(undef,2)
  l8=Vector{Vector{UInt8}}(undef,1)
  empty!(l1)
  empty!(l2)
  empty!(l3)
  empty!(l4)
  empty!(l5)
  empty!(l6)
  empty!(l7)
  empty!(l8)
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
  l1=Vector{Vector{UInt8}}(undef,81)
  l2=Vector{Vector{UInt8}}(undef,27)
  l3=Vector{Vector{UInt8}}(undef,9)
  l4=Vector{Vector{UInt8}}(undef,3)
  l5=Vector{Vector{UInt8}}(undef,1)
  empty!(l1)
  empty!(l2)
  empty!(l3)
  empty!(l4)
  empty!(l5)
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

function update2seq!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  for i in eachindex(blocks)
    append!(tw.tree2[1],blocks[i])
    compressPairs!(tw)
  end
end

function update3seq!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  for i in eachindex(blocks)
    append!(tw.tree3[1],blocks[i])
    compressTriples!(tw)
  end
end

function updateSeq!(tw::Twistree,blocks::Vector{Vector{UInt8}})
  tasks=Task[]
  push!(tasks,@spawn update2seq!(tw,blocks))
  push!(tasks,@spawn update3seq!(tw,blocks))
  for i in 1:2
    wait(tasks[i])
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
  for i in 1:head
    append!(tw.tree2[1],blocks[i])
    compressPairs!(tw)
  end
  bodyHash=OffsetArray(Vector{UInt8}[],0:-1)
  for i in 0:body-1
    push!(bodyHash,UInt8[])
  end
  @threads for i in 0:body-1
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
      head=3*head+length(tw.tree3[i])÷blockSize
    end
  end # the number of blocks already pushed into tree3 mod 243
  if head>0
    head=243-head
  end # the number of more blocks to push to get a multiple of 243
  if head>len
    head=len
  end
  body=(len-head)÷243
  if body<0
    body=0
  end
  tail=head+243*body
  for i in 1:head
    append!(tw.tree3[1],blocks[i])
    compressTriples!(tw)
  end
  bodyHash=OffsetArray(Vector{UInt8}[],0:-1)
  for i in 0:body-1
    push!(bodyHash,UInt8[])
  end
  @threads for i in 0:body-1
    bodyHash[i]=compress243Blocks(tw,blocks,head+1+243*i)
  end
  for i in 0:body-1
    append!(tw.tree3[6],bodyHash[i])
    compressTriples243!(tw)
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

"""
    update!(tw,data::Vector{UInt8}[,parseq])

Update a Twistree with some data. `parseq` can be
- :sequential
- :parallel
- :default

If you have more than 62208 bytes of data and they don't fit in RAM,
you should feed them to `update!` at least 31104 bytes at a time,
or at least between 7776(*n*+2) and 8192(*n*+2) bytes at a time where 
*n* is the number of threads your CPU has.
# Examples:
```julia
  tw=keyedTwistree("")
  initialize!(tw)
  buf=read(file,65536)
  update!(tw,buf)
  buf=read(file,65536)
  update!(tw,buf)
  hash=finalize!(tw)
```
"""
function update!(tw::Twistree,data::Vector{UInt8},parseq::Symbol=:default)
  # Check that the Twistree has been initialized
  if length(tw.tree2)==0 || length(tw.tree3)==0
    error("call initialize before update")
  end
  blocks=blockize!(data,tw.partialBlock)
  if parseq==:default
    if length(blocks)>=parBreakEvenTwistree
      parseq=:parallel
    else
      parseq=:sequential
    end
  end
  if parseq==:sequential
    updateSeq!(tw,blocks)
  else
    updatePar!(tw,blocks)
  end
end

"""
    finalize!(tw::Twistree)

Complete processing the data in the Twistree and return the hash.
Use after `initialize!` and `update!`.
"""
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

"""
    hash!(tw,data::Vector{UInt8}[,parseq])

Hashes a block of data that's all in RAM. Equivalent to calling
`initialize!`, `update!`, and `finalize!`. `parseq` is the same as
in `update!`.
"""
function hash!(tw::Twistree,data::Vector{UInt8},parseq::Symbol=:default)
  # convenience function if the data all fit in RAM
  initialize!(tw)
  update!(tw,data,parseq)
  finalize!(tw)
end

include("benchmark.jl")

end # module WringTwistree
