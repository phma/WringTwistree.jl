# WringTwistree
Wring is a whole-message cipher. This is like a block cipher, but the block can be arbitrarily large, up to about 3 GiB. Wring can also be used as a length-preserving all-or-nothing transform.

Twistree is a hash function. It constructs two trees out of the blocks of data, runs the compression function at each node of the trees, and combines the results with the compression function.

Both algorithms are keyed. The key is turned into 96 16-bit words, which are then used to make three S-boxes. The key can be any byte string, including the empty string.

# Features
A round consists of four operations:

1. The `mix3Parts` operation splits the message or block in three equal parts and mixes them nonlinearly. This provides both diffusion and nonlinearity. The number of rounds in Wring increases logarithmically with message size so that diffusion spreads to the entire message.
2. The three key-dependent 8×8 S-boxes provide confusion and 
resist linear cryptanalysis.
3. Rotating by the population count thwarts integral and differential cryptanalysis by moving the difference around to a different part of the message.
4. Wring's round constant, which is dependent on the byte position as well as the round number, is added to every byte to prevent slide attacks and ensure that an all-zero message doesn't stay that way.
4. Twistree runs a CRC backwards to make the four bytes about to be dropped affect all the other bytes.

# Julia
This is a Julia implementation. The reference implementations, in Rust and Haskell, are in the `wring-twistree` repo.

In the project directory, run `julia --project` at the shell prompt, then in Julia run `using WringTwistree`. You probably want `export JULIA_NUM_THREADS=auto` in your `.profile`, as the algorithms run faster on big inputs when multithreaded. You can then create a Wring, a Twistree, and some byte vectors and encrypt and hash them.

Before encrypting, decrypting, or hashing, and after upgrading Julia, run `setBreakEven()`. This sets the break-even points for Wring and Twistree. When given more data than the break-even points, the functions will handle them in parallel.

# Test vectors
Test vectors are in `test/runtests.jl`. To run them, type `]` to enter Pkg mode, then `test`.
