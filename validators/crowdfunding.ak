use cardano/assets.{lovelace_of}
use cardano/transaction.{Transaction, OutputReference, InlineDatum}
use aiken/crypto.{VerificationKeyHash}
use aiken/collection/list

pub type Datum {
  admin_pkh: VerificationKeyHash,
  current_fund: Int, // In ADA
  target_fund: Int // In ADA
}

pub type Redeemer {
  UserContribute
  AdminClaim
}

validator crowdfunding {
  spend(datum: Option<Datum>, redeemer: Redeemer, utxo: OutputReference, self: Transaction) {
    // Extract all information in datum
    expect Some(Datum { admin_pkh, current_fund, target_fund }) = datum

    // Extract all related information in transaction
    let Transaction { inputs, outputs, ..} = self

    // Get spending utxo
    expect Some(spending_utxo) = inputs |> list.find(fn(input) { input.output_reference == utxo })

    when redeemer is {
      UserContribute -> {
        // Get continuing output which is sent to CrowdFunding smart contract address
        expect Some(output_to_contract) = outputs |> list.find(fn(output) { output.address == spending_utxo.output.address })

        // Extract new datum in continuing output
        expect InlineDatum(new_data) = output_to_contract.datum
        expect new_datum: Datum = new_data

        // New current fund = previous current fund + contributed amount
        let is_new_current_fund_correct =
          (new_datum.current_fund - current_fund) * 1_000_000 ==
            lovelace_of(output_to_contract.value) - lovelace_of(spending_utxo.output.value)

        // New current fund less than or equal target fund
        let is_new_current_fund_less_than_or_equal_target_fund = new_datum.current_fund <= target_fund

        // Other fields in datum must be unchanged (admin_pkh, target_fund)
        let is_admin_pkh_unchanged = admin_pkh == new_datum.admin_pkh
        let is_target_fund_unchanged = target_fund == new_datum.target_fund

        // Check all conditions and add trace messages
        if (!is_new_current_fund_correct) {
          trace @"[Contract Error]: new current fund must be correct"
          False
        } else if (!is_new_current_fund_less_than_or_equal_target_fund) {
          trace @"[Contract Error]: new current fund must be less than or equal target fund"
          False
        } else if (!is_admin_pkh_unchanged) {
          trace @"[Contract Error]: admin public key hash must be unchanged"
          False
        } else if (!is_target_fund_unchanged) {
          trace @"[Contract Error]: target fund must be unchanged"
          False
        } else {
          True
        }
      }

      AdminClaim -> {
        // Only claim when current_fund = target_fund
        let is_claimable = current_fund == target_fund

        // Must be signed by admin_pkh
        let is_admin = list.has(self.extra_signatories, admin_pkh)

        // Check all conditions and add trace messages
        if (!is_claimable) {
          trace @"[Contract Error]: current fund is not equal to target fund"
          False
        } else if (!is_admin) {
          trace @"[Contract Error]: you're not the admin"
          False
        } else {
          True
        }
      }
    }
  }

  else(_) {
    fail
  }
}
