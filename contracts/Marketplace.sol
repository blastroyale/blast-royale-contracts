// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct Listing {
  address owner;
  bool is_active;
  uint256 token_id;
  uint256 price;
}

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract Marketplace is ReentrancyGuard  {

  using SafeMath for uint256;

  uint256 public listing_count = 0;
  mapping (uint256 => Listing) public listings;
  ERC721 private erc721_contract;
  ERC20 private erc20_contract;

  /// @notice Event Listed 
  event Listed(
		uint listingId,
		uint tokenId,
		address seller,
		uint256 price
	);

  /// @notice Token constructor
  /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
  /// @param erc721_address Address of the NFT Contract.
  /// @param erc20_address Address of the Primary Token Contract.
  constructor(address erc721_address, address erc20_address) {
    erc721_contract = ERC721(erc721_address);
    erc20_contract = ERC20(erc20_address);
  }

  /// @notice add a Listing to the Marketplace
  /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
  /// @param token_id NFT TokenId.
  /// @param price Price in NFTs.
  function addListing(uint256 token_id, uint256 price) public nonReentrant
  {
    listings[listing_count] = Listing(
      msg.sender,
      true,
      token_id,
      price
    );
    listing_count = listing_count.add(1);
    erc721_contract.transferFrom(
      msg.sender,
      address(this),
      token_id);
    :
  }

  /// @notice Remove a Listing from the Marketplace
  /// @dev Marks Listing as not active object and transfers the Token back
  /// @param listing_id NFT Listing Id.
  function removeListing(uint256 listing_id) public nonReentrant
  {
    require(listings[listing_id].owner == msg.sender, "Must be owner");
    require(listings[listing_id].is_active, "Must be active");
    listings[listing_id].is_active = false;
    erc721_contract.transferFrom(
      address(this),
      msg.sender,
      listings[listing_id].token_id
    );
  }

  /// @notice Buys a listed NFT
  /// @dev Trabsfers both the ERC20 token (price) and the NFT.
  /// @param listing_id NFT Listing Id.
  function buy(uint256 listing_id) public nonReentrant
  {
    require(listings[listing_id].is_active, "Must be active");
    listings[listing_id].is_active = false;
    erc20_contract.transferFrom(
      msg.sender,
      listings[listing_id].owner,
      listings[listing_id].price
    );
    erc721_contract.transferFrom(
      address(this),
      msg.sender,
      listings[listing_id].token_id
    );
  }

  function getActiveListings(uint256 index) public view returns(uint256)
  {
    uint256 j;
    for(uint256 i=0; i<listing_count; i++)
    {
      if(listings[i].is_active)
      {
        if(index == j)
        {
          return i;
        }
        j+=1;
      }
    }
    return 0;
  }

  function getListingsByOwner(address owner, uint256 index) public view returns(uint)
  {
    uint256 j;
    for(uint256 i=0; i<listing_count; i++)
    {
      if(listings[i].is_active && listings[i].owner == owner)
      {
        if(index == j)
        {
          return i;
        }
        j+=1;
      }
    }
    return 0;
  }

  function getListingsByOwnerCount(address owner) public view returns(uint256)
  {
    uint256 result;
    for(uint256 i=0; i<listing_count; i++)
    {
      if(listings[i].is_active && listings[i].owner == owner)
      {
        result+=1;
      }
    }
    return result;
  }

  function getActiveListingsCount() public view returns(uint256)
  {
    uint256 result;
    for(uint256 i=0; i<listing_count; i++)
    {
      if(listings[i].is_active)
      {
        result+=1;
      }
    }
    return result;
  }
}

