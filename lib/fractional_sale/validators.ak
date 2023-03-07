use aiken/list
use aiken/transaction.{Input, OutputReference, Transaction}
use aiken/transaction/value.{Value}
use fractional_sale/address
use fractional_sale/data
use fractional_sale/datums.{Datum, PublicKeyHash, TokenInfo}
use fractional_sale/redeemers.{BuyAmount}

fn find_input_value(possible_input: Option<Input>) -> Value {
  when possible_input is {
    Some(possible_input) -> possible_input.output.value
    None -> error @"no value on spending input"
  }
}

fn must_be_signed_by(transaction: Transaction, vk: PublicKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

pub fn purchase_validation(
  datum: Datum,
  tx: Transaction,
  output_reference: OutputReference,
  amount: BuyAmount,
) -> Bool {
  let validating_input =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  let validating_value = find_input_value(validating_input)
  let script_addr = address.find_input_address(validating_input)
  let seller_addr = address.create_address(datum.owner.pkh, datum.owner.sc)
  let pay_token =
    TokenInfo(datum.cost.pid, datum.cost.tkn, amount.amt * datum.cost.amt)
  let pay_value =
    value.from_asset(
      datum.bundle.pid,
      datum.bundle.tkn,
      amount.amt * datum.bundle.amt,
    )
  let partial_value = value.add(validating_value, value.negate(pay_value))
  let outbound_output =
    list.find(tx.outputs, fn(output) { output.address == script_addr })
  expect outbound_datum: Datum = data.find_outbound_datum(outbound_output)
  list.and(
    [
      // single script input
      (address.count_script_inputs(tx.inputs, script_addr, 0) == 1)?,
      // single script output
      (address.count_script_outputs(tx.outputs, script_addr, 0) == 1)?,
      // check for valid bundle size
      redeemers.valid_bundle_size(amount)?,
      // the continuing utxo must have a correct datum
      datums.purchase_datum_check(datum, outbound_datum)?,
      // the seller gets paid what they want
      address.find_token_payout(seller_addr, pay_token, tx.outputs)?,
      // the leftover partial token gets send back to the script
      address.find_exact_payout(script_addr, partial_value, tx.outputs)?,
      // owner can not lie
      (value.quantity_of(validating_value, datum.bundle.pid, datum.bundle.tkn) >= amount.amt * datum.bundle.amt)?,
    ],
  )
}

pub fn update_validation(
  datum: Datum,
  tx: Transaction,
  output_reference: OutputReference,
) -> Bool {
  let validating_input =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  let script_addr = address.find_input_address(validating_input)
  let outbound_output =
    list.find(tx.outputs, fn(output) { output.address == script_addr })
  expect outbound_datum: Datum = data.find_outbound_datum(outbound_output)
  list.and(
    [
      // the owner must sign it
      must_be_signed_by(tx, datum.owner.pkh)?,
      // a utxo must go back to the script
      address.find_cont_payout(script_addr, tx.outputs)?,
      // the owner of the cont utxo must remain constant
      datums.constant_ownership(datum, outbound_datum)?,
      // single script input
      (address.count_script_inputs(tx.inputs, script_addr, 0) == 1)?,
      // single script output
      (address.count_script_outputs(tx.outputs, script_addr, 0) == 1)?,
    ],
  )
}

pub fn remove_validation(
  datum: Datum,
  tx: Transaction,
  output_reference: OutputReference,
) -> Bool {
  let validating_input =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  let validating_value = find_input_value(validating_input)
  let script_addr = address.find_input_address(validating_input)
  let seller_addr = address.create_address(datum.owner.pkh, datum.owner.sc)
  list.and(
    [
      // owner must sign it
      must_be_signed_by(tx, datum.owner.pkh)?,
      // owner must get the utxo back
      address.find_exact_payout(seller_addr, validating_value, tx.outputs)?,
      // single script input
      (address.count_script_inputs(tx.inputs, script_addr, 0) == 1)?,
      // no script outputs
      (address.count_script_outputs(tx.outputs, script_addr, 0) == 0)?,
    ],
  )
}
