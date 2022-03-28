# Blast Royale - Metadata

Every BlastNFT is represented by an Image and its metadata. To generate the metadata for an NFT, first the Image needs to be uploaded to a permanent Storage option (IPFS, Arweave, Filecoin...). The image of the NFT and the metadata will be then stored as a Json file.

The metadata of an NFT, developed according to the ERC721 standard, is generally saved in the IPFS, a peer-to-peer protocol for saving multimedia files. This metadata is pinned to the protocol and returned as a hash to the Smart Contract. The resulting url, in the form https://ipfs.io/ipfs/<hash>, is saved in the Smart Contract storage and associated to the ID of the corresponding token.

BlastRoyale is pinning/storing all of the files on IPFS.

## Metadata
The main parameters in the json file are : name, decription, image (IPFS URI).

The attributes are.

- Level : 1-50
- Generation : 1 (NFT has been minted), 2, 3, 4... (have been replicated).
- Edition : Name of the Edition (OGs, Winter 2022...)
- Category : Helmet, Armour, Shield, Amulet, Weapon
- Faction : Order, Chaos, Organic, Dark, Underworld, Celestial, Middle
- Adjective : Regular, Cool, Ornate, Posh, Exquisite, Majestic, Marvelous, Magnificent, Royal, Divine
- Rarity : Common, Common+, Uncommon, Uncommon+, Rare, Rare+, Epic, Epic+, Legendary, Legendary+
- Manufacturer (string)
- Grade (roman numbers - srting)
- Material : Plastic, Steel, Bronze, Carbon, Golden
- Max Durability
- Max Level : Depends on Rarity
- Initial Replication Counter
- Tuning : For branding opportunities

Off-chain metadata (mutable) : This is a Link in the metadata pointing to a dynamic API hosted by First Light Games. It contains stats of the NFTs : kills, games...

```json
{
  "name": "BlastRoyale#117",
  "description": "Super Laser",
  "image" : "ipfs://ipfs/QmUoc2LDDnHxHsesLXtpxTLupzVuyfVkJomWWHmvKNCjrL/image.png",
  "attributes": [
    {
      "trait_type": "Level",
      "value": 3 
    },
    {
      "trait_type": "Category",
      "value": "Weapon" 
    },
    {
      "trait_type": "Faction",
      "value": "Chaos" 
    },
    {
      "trait_type": "Adjective",
      "value": "Exquisite" 
    },
    {
      "trait_type": "Rarity",
      "value": "Rare" 
    },
    {
      "trait_type": "Manufacturer",
      "value": "Hyperion" 
    },
    {
      "trait_type": "Grade",
      "value": "II" 
    },
    {
      "trait_type": "Material",
      "value": "Steel" 
    },
  ],
  "external_url" : "https://blastroyale.com/nfts/117"
}
```

## References
- [Opensea standards](https://docs.opensea.io/docs/metadata-standards)
