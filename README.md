# Blast royale contracts

This project contain all the contracts related nft, lootbox, tokenVesting, repairing, repair, upgrader and scrapping

## To deploy all the contracts: the following line will deploy all the above mentioned contracts

```shell
npx hardhat deployAll --network mumbai
```

## Verification for deployed contracts

```shell
npx hardhat verifyAll --network mumbai
```

## To flip usingMatic flag with one command:

```shell
npx hardhat flipUsingMatic --network mumbai
```

## To pause all the contracts with one command:

```shell
npx hardhat pauseAll --network mumbai
```


## To grant roles to related contracts

```shell
npx hardhat run scripts/grantRole.ts --network mumbai
```
