# SB

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sb, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sb](https://hexdocs.pm/sb).

# Execute

## mix test

---

## Test functionalities:

- Testing for creation of a genesis, called the coinbase transaction
- Testing for mining of the blocks
- Testing for a regular transaction happening between two random nodes, one of which would be a node receiving the BTC's as a part of the coinbase transaction
- Implementation of the distributed protocol for the system
- Implemenation of distributed verification of the mined blocks. The block that surpasses verification threshold count first is considered to be the legit one. Other generated block(s)/mining job(s) is(are) discarded

---

# Modular Components

- CryptoHandle: Collection of libraries that facilitates crypto hash generation and verification implementation
- Simple Bitcoin Application : Application wrapper from Elixir implementation
- Application supervisor: Primary top level supervisor for running OTP processes
- Master: The overarching process that controls/invokes bitcoin miners/users and initializes the distributed network
- Node: Implementation of bitcoin mining/user interfaces that facilitates transaction and block mining operations
- Wallet: Implementation for Full Service bitcoin protocol based wallet for handling send/receive as well as store BTC
- Transaction: Composition of all transaction related functionalities such as crypto coinbase and standard transaction of BTC

---

# Bonus Implementation

- Distributed implementation of the protocol
- Implementation of the public hash and BTC addresses as they are
- Implementation of the PubKeyScript & SigScript instead of just a regular digital signature authentication
- Original Genesis transaction
- Complete implementation of the wallet and mining.

---

## Contributors

Jay Patel

UFID: 4145 1618

Mukul Chand Yadav

UFID: 7585 9623
