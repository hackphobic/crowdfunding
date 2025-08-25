# crowdfunding

## 1. Compile contract

```sh
cd crowdfunding
aiken build -t verbose
```

## 2. Run scripts to test step-by-step

### Install dependencies

```sh
cd crowdfunding/scripts
npm install
```

### Setup environment variables

Create your own .env file and fill out all the variables

```sh
cp .env.example .env
```

BLOCKFROST_API_KEY: Please go to website https://blockfrost.io/ and create your own API key

BLOCKFROST_URL: Blockfrost URL (e.g: https://cardano-preprod.blockfrost.io/api/v0)

NETWORK: Cardano network (e.g: Preprod)

ADMIN_ADDRESS: Your admin address

ADMIN_MNEMONIC: Your admin mnemonic phrase

USER_MNEMONIC: Your user mnemonic phrase

### 2.1. Initialize

Check script 1-initialize.js, you can change your targetFund if needed:

```js
// Prepare data for datum
const currentFund = 0n;
const targetFund = 100n;
```

Run script:

```sh
node 1-initialize.js
```

You will get some output like this:

```sh
Contract Address:  addr_test1wrdzsldt65nfpsy3e7gzfmfhstuwm3wjz5qxyt8e5jn0jegzlz7z2
txHash:  306f36a5332040da394a1652ef792b9214f92b60fc46e201a9f33d176a0d1245
```

Go to explorer: https://preprod.cardanoscan.io
to check your contract address and transaction hash

Wait a couple of minutes to make sure the transaction has been confirmed

After that, you can run script query_info.js to check the current status of the crowdfunding:

```sh
node query_info.js
```

You will receive some information like this:

```sh
Contract Address:  addr_test1wrdzsldt65nfpsy3e7gzfmfhstuwm3wjz5qxyt8e5jn0jegzlz7z2
Single UTxO of Contract Address:  [
  {
    address: 'addr_test1wrdzsldt65nfpsy3e7gzfmfhstuwm3wjz5qxyt8e5jn0jegzlz7z2',
    tx_hash: '306f36a5332040da394a1652ef792b9214f92b60fc46e201a9f33d176a0d1245',
    tx_index: 0,
    output_index: 0,
    amount: [ [Object] ],
    block: '305fd7aea0b2eace2596bd9c2ab2a236bbb32d5fc42a9076a93d1401f78560e2',
    data_hash: 'f65c82400dabf9c504488e6e66b6d0fc63162b9295b81599e085ad2eda977c53',
    inline_datum: 'd8799f581cf731f4b4122b56047427adc277f696373c9f67216f4c8b14a315ae01001864ff',
    reference_script_hash: null
  }
]
Amount of this UTxO:  [ { unit: 'lovelace', quantity: '2000000' } ]
currentFund:  0
targetFund:  100
All transactions of Contract Address: ...
```

### 2.2. User contribute

Check script 2-user-contribute.js, change your amount:

```js
// Amount contribute to the crowdfunding
const amountContribute = 5n;
```

Run script:

```sh
node 2-user-contribute.js
```

You will get some output and the transaction hash:

```sh
txHash:  8caaa7442c55e316eaaadaa1ac147accbba6c258daf1a4e6523ea47652f0933a
```

Go to explorer, wait until it has been confirmed and check your transaction for more details

After that, you can run script query_info.js again to check the current status of the crowdfunding:

```sh
node query_info.js
```

You will receive some information like this:

```sh
Single UTxO of Contract Address:  ...
Amount of this UTxO:  ...
currentFund:  5
targetFund:  100
All transactions of Contract Address: ...
```

If you try to change the currentFund in new datum to make it wrong like this (change currentFund to 100n):

```js
// Construct the datum
const datum = Data.to(
  new Constr(0, [previousAdminPKH, 100n, BigInt(previousTargetFund)])
);
console.log("datum: ", datum);
```

After running script, you will get the error message from contract:

```sh
Trace [Contract Error]: new current fund must be correct Trace Validator returned false
```

If you try to contribute more than the targetFund:

```js
// Amount contribute to the crowdfunding
const amountContribute = 105n;
```

After running script, you will get the error message from contract:

```sh
Trace [Contract Error]: new current fund must be less than or equal target fund Trace Validator returned false
```

If you try to change the admin pubkey hash in new datum, after running script, you will get the error message from contract:

```sh
Trace [Contract Error]: admin public key hash must be unchanged Trace Validator returned false
```

If you try to change the targetFund in new datum, after running script, you will get the error message from contract:

```sh
Trace [Contract Error]: target fund must be unchanged Trace Validator returned false
```

### 2.3. Admin claim

Run script 3-admin-claim.js:

```sh
node 3-admin-claim.js
```

If the crowdfunding has not completed, you can not claim the funds, after running script, you will get the error message from contract:

```sh
Trace [Contract Error]: current fund is not equal to target fund Trace Validator returned false
```

If you are not the admin, but trying to claim the funds (change mnemonic from admin to user):

```js
// Admin mnemonic
const mnemonic = process.env.USER_MNEMONIC;
```

You will get the error message from contract:

```sh
Trace [Contract Error]: you're not the admin Trace Validator returned false
```

If all conditions are met, after running script, you will get the transaction hash:

```sh
txHash:  410aeeb5a6dd408a43ef67ebd7047ea8e4ad7b54e9e9c5e9f20315bfe5d89f98
```

Go to explorer to get more details about the transaction
