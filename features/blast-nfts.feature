Feature: Blast Royale NFTs
  In order to manage the NFT supply
  As the contract owner
  I want to mint new nfts when required

Scenario: Minting nfts
  Given The nft contract has been deployed
  And The total supply is 0
  And The owner of tokenId 1 is 0
  When 1 new nft with tokenId 1 is minted by address 0 into address 1
  Then The total supply is 1
  And The owner of tokenId 1 is address 1
