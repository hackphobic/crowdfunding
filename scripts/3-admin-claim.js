import { Lucid, Blockfrost, Data, Constr } from "@lucid-evolution/lucid";
import { validatorToAddress } from "@lucid-evolution/utils";
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

    const spendValidator = {
      type: "PlutusV3",
      script: contract.validators[0].compiledCode,
    };

    const contractAddress = validatorToAddress(
      process.env.NETWORK,
      spendValidator
    );
    console.log("Contract Address: ", contractAddress);

    const spendingUtxo = await lucid.utxosAt(contractAddress);
    console.log("spendingUtxo: ", spendingUtxo);

    // Admin mnemonic
    const mnemonic = process.env.ADMIN_MNEMONIC;

    lucid.selectWallet.fromSeed(mnemonic);

    const senderAddress = await lucid.wallet().address();
    console.log("senderAddress: ", senderAddress);

    // 0: UserContribute, 1: AdminClaim
    const redeemer = Data.to(new Constr(1, []));
    console.log("redeemer: ", redeemer);

    const tx = await lucid
      .newTx()
      .collectFrom([spendingUtxo[0]], redeemer)
      .attach.SpendingValidator(spendValidator)
      .addSigner(senderAddress)
      .complete();

    const signedTx = await tx.sign.withWallet().complete();

    const txHash = await signedTx.submit();
    console.log("txHash: ", txHash);
  } catch (err) {
    console.log("err: ", err);
  }
})();
