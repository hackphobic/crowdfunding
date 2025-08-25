use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/certificate.{Certificate}
use cardano/governance.{ProposalProcedure, Voter}
use cardano/transaction.{Transaction, OutputReference}
use aiken/crypto.{VerificationKeyHash}

pub type Datum {
  admin_pkh: VerificationKeyHash,
  authen_token: ByteArray,
  current_fund: Int,
  target_fund: Int
}

pub type Redeemer {
  UserContribute
  AdminClaim
}

validator crowdfunding {
  spend(datum: Option<Datum>, redeemer: Redeemer, utxo: OutputReference, self: Transaction) {
    let Transaction { inputs, outputs, ..} = self

    // Authen token must be in spending utxo

    when redeemer is {
      UserContribute -> {
        expect Some(Datum { admin_pkh, authen_token, current_fund, target_fund }) = datum
        
        // Authen token must be in outputs and be sent to crowdfunding smart contract address

        // New fund = previous fund + contributed amount

        // New fund less than or equal target fund

        // Other fields in datum must be unchanged (admin_pkh, authen_token, target_fund)

        True
      }

      AdminClaim -> {
        // Only claim when current_fund = target_fund

        // Must be signed by admin_pkh

        True
      }
    }
  }

  else(_) {
    fail
  }
}
