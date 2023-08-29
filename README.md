# Front Door Contracts

This project contains Front Door smart contracts:

- FNDR Token for user tests
- FNDR Faucet to request FNDR Tokens
- Recruitment contract, Front Door main contract

## Deploy to HardHat node

In order to deploy the contracts into a HardHat development node, execute:
`npx hardhat run scripts/deployAllHardHat.js --network localhost`

This script will return:

```
Front Door Token deployed to:  0x998abeb3E57409262aE5b751f60747921B33613E
Front Door Faucet deployed to:  0x70e0bA845a1A0F2DA3359C97E0285013525FFC49
Front Door Recruiter Contract deployed to:  0x70e0bA845a1A0F2DA3359C97E0285013525FFC49
Company FNDR Tokens:  1000.0
Referrer FNDR Tokens:  1000.0
Referree FNDR Tokens:  1000.0
Faucet FNDR Tokens:  5000000.0
```

### Note

For develment purposes we are using the following name accounts:
`const [owner, company, referrer, referree, frontDoorWallet] = await ethers.getSigners();`

Meaning that HH account 0 is the owner, HH account 1 is the company ...

## Test

To test the contracts:
`npx hardhat test`
