import { Lucid, Blockfrost, Data, Constr } from "@lucid-evolution/lucid";
import { validatorToAddress, getAddressDetails } from "@lucid-evolution/utils";
import contract from "../plutus.json" assert { type: "json" };
import * as dotenv from "dotenv";
dotenv.config();

(async function main() {
  const lucid = await Lucid(
    new Blockfrost(process.env.BLOCKFROST_URL, process.env.BLOCKFROST_API_KEY),
    process.env.NETWORK
  );

  const adminAddress = process.env.ADMIN_ADDRESS;
  const adminPKH = getAddressDetails(adminAddress).paymentCredential?.hash;
  console.log("Admin PKH: ", adminPKH);

  const spendValidator = {
    type: "PlutusV3",
    script: contract.validators[0].compiledCode,
  };

  const contractAddress = validatorToAddress(
    process.env.NETWORK,
    spendValidator
  );
  console.log("Contract Address: ", contractAddress);

  // Admin mnemonic
  const mnemonic = process.env.ADMIN_MNEMONIC;

  lucid.selectWallet.fromSeed(mnemonic);

  const currentFund = 0n;
  const targetFund = 100n;

  const datum = Data.to(new Constr(0, [adminPKH, currentFund, targetFund]));
  console.log("datum: ", datum);

  const tx = await lucid
    .newTx()
    .pay.ToContract(
      contractAddress,
      { kind: "inline", value: datum },
      { lovelace: 2_000_000n }
    )
    .complete();

  const signedTx = await tx.sign.withWallet().complete();
  const txHash = await signedTx.submit();
  console.log("txHash: ", txHash);
})();
