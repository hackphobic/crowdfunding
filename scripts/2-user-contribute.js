import { Lucid, Blockfrost, Data, Constr } from "@lucid-evolution/lucid";
import { validatorToAddress } from "@lucid-evolution/utils";
import * as BF from "@blockfrost/blockfrost-js";
import contract from "../plutus.json" assert { type: "json" };
import * as dotenv from "dotenv";
dotenv.config();

(async function main() {
  try {
    const lucid = await Lucid(
      new Blockfrost(
        process.env.BLOCKFROST_URL,
        process.env.BLOCKFROST_API_KEY
      ),
      process.env.NETWORK
    );

    const API = new BF.BlockFrostAPI({
      projectId: process.env.BLOCKFROST_API_KEY,
    });

    // Read validator from plutus.json
    const spendValidator = {
      type: "PlutusV3",
      script: contract.validators[0].compiledCode,
    };

    // Get contract address
    const contractAddress = validatorToAddress(
      process.env.NETWORK,
      spendValidator
    );
    console.log("Contract Address: ", contractAddress);

    // Read current datum belongs to the single utxo of contract address
    // Note: Read utxo by API to get datum info
    const utxo = await API.addressesUtxos(contractAddress);
    console.log("utxo: ", utxo);

    const previousDatumHash = utxo[0].data_hash;
    const previousDatum = await API.scriptsDatum(previousDatumHash);
    console.log("previousDatum: ", previousDatum);

    const previousAdminPKH = previousDatum.json_value.fields[0]["bytes"];
    console.log("previousAdminPKH: ", previousAdminPKH);

    const previousCurrentFund = previousDatum.json_value.fields[1]["int"];
    console.log("previousCurrentFund: ", previousCurrentFund);

    const previousTargetFund = previousDatum.json_value.fields[2]["int"];
    console.log("previousTargetFund: ", previousTargetFund);

    // Get utxo to build transaction
    // Note: Read utxo by lucid to build transaction
    const spendingUtxo = await lucid.utxosAt(contractAddress);
    console.log("spendingUtxo: ", spendingUtxo);

    // User mnemonic
    const mnemonic = process.env.USER_MNEMONIC;

    lucid.selectWallet.fromSeed(mnemonic);

    // Amount contribute to the crowdfunding
    const amountContribute = 95n;

    // Redeemer Actions:
    // 0 - UserContribute, 1 - AdminClaim
    const redeemer = Data.to(new Constr(0, []));
    console.log("redeemer: ", redeemer);

    // Calculate new current fund for new datum
    const currentFund = BigInt(previousCurrentFund) + amountContribute;
    console.log("currentFund: ", currentFund);

    // Construct the datum
    const datum = Data.to(
      new Constr(0, [previousAdminPKH, currentFund, BigInt(previousTargetFund)])
    );
    console.log("datum: ", datum);

    // Calculate final amount to send to contract
    // finalAmount = previousAmount + amountContribute
    const finalAmount =
      spendingUtxo[0].assets.lovelace + amountContribute * 1_000_000n;
    console.log("finalAmount: ", finalAmount);

    const tx = await lucid
      .newTx()
      .collectFrom([spendingUtxo[0]], redeemer)
      .attach.SpendingValidator(spendValidator)
      .pay.ToContract(
        contractAddress,
        { kind: "inline", value: datum },
        { lovelace: finalAmount }
      )
      .complete();

    const signedTx = await tx.sign.withWallet().complete();

    const txHash = await signedTx.submit();
    console.log("txHash: ", txHash);
  } catch (err) {
    console.log("err: ", err);
  }
})();
