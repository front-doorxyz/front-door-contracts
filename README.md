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
Deploying Contracts...
Front Door Token deployed to:  0x5FbDB2315678afecb367f032d93F642f64180aa3
Front Door Faucet deployed to:  0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Configuring roles in Front Door Token...
Front Door Recruiter Contract deployed to:  0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
Requesting tokens for company and referrer...
Company FNDR Tokens:  1000.0
Referrer FNDR Tokens:  1000.0
```

### Note

For develment purposes we are using the following name accounts:
`const [owner, company, referrer, referree, frontDoorWallet] = await ethers.getSigners();`

Meaning that HH account 0 is the owner, HH account 1 is the company ...

## Test

To test the contracts:
`npx hardhat test`
