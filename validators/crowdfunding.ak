use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Script}
use cardano/assets.{PolicyId, lovelace_of, quantity_of}
use cardano/transaction.{InlineDatum, Input, OutputReference, Transaction}

// Name of the NFT which will be holding the ADA & CF tokens of this contract
const stt_asset_name: ByteArray = config.stt_asset_name

// Asset_name of the CF token
const cf_asset_name: ByteArray = config.cf_asset_name

// Price per CF token
const price_per_token: Int = config.price_per_token

// Target in Lovelace
const target_fund: Int = config.target_fund

// crowdfund owner address
const admin_pkh: VerificationKeyHash = config.admin_pkh

// This UTXO needs to be consumed when deploying a new crowdfund
const utxo_ref: OutputReference = config.utxo_ref

pub type Redeemer {
  UserContribute
  AdminClaim
}

validator crowdfunding(utxo_ref: OutputReference) {
  spend(
    _datum: Option<Void>,
    redeemer: Redeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    // Extract all related information in transaction
    let Transaction { inputs, outputs, .. } = self

    // Get spending utxo
    expect Some(spending_utxo) =
      inputs |> list.find(fn(input) { input.output_reference == utxo })

    // get contract own hash
    expect Script(own_script_hash) =
      spending_utxo.output.address.payment_credential

    when redeemer is {
      UserContribute -> {
        // PURCHASED_CF_AMOUNT = INPUT_STT_CF - OUTPUT_STT_CF 
        // TOTAL_PRICE = TOKEN_PRICE * PURCHASED_CF_AMOUNT
        // OUTPUT_STT_ADA == (INPUT_STT_ADA + TOTAL_PRICE)

        // Retrieve the STT output
        expect Some(stt_output) =
          outputs
            |> list.find(
                fn(output) {
                  quantity_of(output.value, own_script_hash, stt_asset_name) > 0
                },
              )
        // Retrieve the STT input
        expect Some(stt_input) =
          inputs
            |> list.find(
                fn(input) {
                  let value = input.output.value
                  quantity_of(value, own_script_hash, stt_asset_name) > 0
                },
              )
        // extract the needed info from the STT
        let input_stt_ada: Int = lovelace_of(stt_input.output.value)
        let output_stt_ada: Int = lovelace_of(stt_output.value)
        let input_stt_cf: Int =
          quantity_of(stt_input.output.value, own_script_hash, cf_asset_name)
        let output_stt_cf: Int =
          quantity_of(stt_output.value, own_script_hash, cf_asset_name)

        // calculate the needed values:
        let purchased_cf_amount: Int = input_stt_cf - output_stt_cf
        let total_price: Int = purchased_cf_amount * price_per_token
        let expected_paid_ada: Int = input_stt_ada + total_price
        let paid_amount_is_correct = output_stt_ada == expected_paid_ada

        let is_new_current_fund_less_than_or_equal_target_fund =
          output_stt_ada <= target_fund

        // The STT NFT must be forwarded to this validator
        let stt_is_forwarded_to_this_validator =
          stt_input.output.address == stt_output.address

        // Check all conditions and add trace messages
        if !stt_is_forwarded_to_this_validator {
          trace @"[Contract Error]: the STT NFT must be forwarded to the contract"
          False
        } else if !paid_amount_is_correct {
          trace @"[Contract Error]: paid amount is incorrect amount"
          False
        } else if !is_new_current_fund_less_than_or_equal_target_fund {
          trace @"[Contract Error]: new current fund must be less than or equal target fund"
          False
        } else {
          True
        }
      }

      AdminClaim -> {
        // Retrieve the STT input
        expect Some(stt_input) =
          inputs
            |> list.find(
                fn(input) {
                  let value = input.output.value
                  quantity_of(value, own_script_hash, stt_asset_name) > 0
                },
              )
        let input_stt_ada: Int = lovelace_of(stt_input.value)
        // Only claim when current_fund = target_fund
        let is_claimable = input_stt_ada >= target_fund

        // Must be signed by admin_pkh
        let is_admin = list.has(self.extra_signatories, admin_pkh)

        // Check all conditions and add trace messages
        if !is_claimable {
          trace @"[Contract Error]: current fund is not equal to target fund"
          False
        } else if !is_admin {
          trace @"[Contract Error]: you're not the admin"
          False
        } else {
          True
        }
      }
    }
  }

  mint(_redeemer: Data, policy_id: PolicyId, self: Transaction) {
    // Used when a new crowdfund is deployed
    // Purpose: to double check the minted amounts of the STT NFT & CF tokens
    let Transaction { inputs, outputs, mint, .. } = self

    let is_output_consumed =
      list.any(inputs, fn(input) { input.output_reference == utxo_ref })

    let stt_quantity = quantity_of(mint, policy_id, stt_asset_name)
    let one_stt_minted = stt_quantity == 1

    let cf_token_quantity = quantity_of(mint, policy_id, cf_asset_name)
    let correct_target_minted =
      cf_token_quantity * price_per_token == target_fund

    is_output_consumed? && one_stt_minted? && correct_target_minted?
  }

  else(_) {
    fail
  }
}
