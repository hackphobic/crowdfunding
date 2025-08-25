import { validatorToAddress } from "@lucid-evolution/utils";
import * as BF from "@blockfrost/blockfrost-js";
import contract from "../plutus.json" assert { type: "json" };
import * as dotenv from "dotenv";
dotenv.config();

(async function main() {
  const API = new BF.BlockFrostAPI({
    projectId: process.env.BLOCKFROST_API_KEY,
  });

  const spendValidator = {
    type: "PlutusV3",
    script: contract.validators[0].compiledCode,
  };

  const contractAddress = validatorToAddress(
    process.env.NETWORK,
    spendValidator
  );
  console.log("Contract Address: ", contractAddress);

  const utxo = await API.addressesUtxos(contractAddress);
  console.log("Single UTxO of Contract Address: ", utxo);

  console.log("Amount of this UTxO: ", utxo[0].amount);

  const datumHash = utxo[0].data_hash;
  const datum = await API.scriptsDatum(datumHash);

  const adminPKH = datum.json_value.fields[0]["bytes"];
  console.log("adminPKH: ", adminPKH);

  const currentFund = datum.json_value.fields[1]["int"];
  console.log("currentFund: ", currentFund);

  const targetFund = datum.json_value.fields[2]["int"];
  console.log("targetFund: ", targetFund);

  const allTxs = await API.addressesTransactionsAll(contractAddress);
  console.log("All transactions of Contract Address: ", allTxs);
})();
