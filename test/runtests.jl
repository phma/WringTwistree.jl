using WringTwistree,Test

@test findMaxOrder(85)==54
@test findMaxOrder(1618034)==1000001
@test findMaxOrder(1)==1

key96 = "Водворетраванатраведрова.Нерубидрованатраведвора!"
key30 = "Πάντοτε χαίρετε!"
key6 = "aerate"
# key96 is also used as a plaintext for hashing because 32|96.
text31 = "בראשית ברא אלהים " #-start of Bible
text33 = "árvíztűrő tükörfúrógépek"
wring96 = keyedWring(key96)
wring30 = keyedWring(key30)
wring6 = keyedWring(key6)
wring0 = keyedWring("")

function testVectorWring(wring,plaintext,ciphertext)
  plaintext=Vector{UInt8}(plaintext)
  text=copy(plaintext)
  encrypt!(wring,text)
  ret=text==ciphertext
  if !ret
    println("Expected ciphertext: ",ciphertext,"\nGot: ",text)
  end
  decrypt!(wring,text)
  ret&=text==plaintext
  ret
end

#Test vectors for Wring
@test testVectorWring(wring0,[0,0,0,0,0,0,0,0],
		      [0x77,0x3e,0x34,0x8f,0x48,0xa1,0x24,0x1a])
@test testVectorWring(wring0,[255,255,255,255,255,255,255,255],
		      [0xc7,0xa7,0x58,0xed,0x5c,0x2b,0xb6,0xec])
@test testVectorWring(wring0,"Twistree",
		      [0xa3,0xcf,0xd4,0xa1,0x0d,0x7e,0xb7,0xb3])
@test testVectorWring(wring0,[0,0,0,0,0,0,0,0,0],
		      [0x10,0x10,0x95,0x96,0x90,0xb5,0x97,0xeb,0x38])
@test testVectorWring(wring0,[255,255,255,255,255,255,255,255,255],
		      [0x09,0x0f,0xf3,0x66,0x36,0xa4,0xac,0x8d,0x5c])
@test testVectorWring(wring0,"AllOrNone",
		      [0xee,0x15,0x02,0x05,0xdd,0xa9,0x77,0xe4,0x23])

