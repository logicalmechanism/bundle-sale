use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}

pub type PublicKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type OwnerInfo {
  pkh: PublicKeyHash,
  sc: PublicKeyHash,
}

pub type TokenInfo {
  pid: ByteArray,
  tkn: ByteArray,
  amt: Int,
}

pub type Datum {
  owner: OwnerInfo,
  bundle: TokenInfo,
  cost: TokenInfo,
}

pub fn constant_ownership(inbound_datum: Datum, outbound_datum: Datum) -> Bool {
  inbound_datum.owner == outbound_datum.owner
}

pub fn purchase_datum_check(inbound_datum: Datum, outbound_datum: Datum) -> Bool {
  inbound_datum == outbound_datum
}
