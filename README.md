# Rewards distribution contract

This contract will be responsible for distributing rewards on users who lock their tokens into it. The owner of the contract will set the rewards epochs and amount and in the end of each epoch the contract will distribute these rewards to the addresses that were lock on that epoch based on the amount of tokens they locked.

# How to test:

Build: <br>
`foundry build`

Run tests on ethereum fork: <br>
`foundry test --fork-url https://mainnet.infura.io/v3/<YOUR INFURA KEY>`

# How to generate npm package with contract abis and factories:

Install dependencies: <br>
`npm ci`

Generate package: <br>
`npm run package:generate`

Build package: <br>
`npm run package:build`
