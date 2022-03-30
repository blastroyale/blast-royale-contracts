// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Listing {
  address owner;
  bool isActive;
  uint256 tokenId;
  uint256 price;
}

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract Marketplace is ReentrancyGuard, Ownable  {

  using SafeMath for uint256;

  uint256 public listingCount = 0;
  uint256 public activeListingCount = 0;
  uint256 private fee;
  address private treasuryAddress;

  mapping (uint256 => Listing) public listings;
  ERC721 private erc721Contract;
  ERC20 private erc20Contract;

  /// @notice Event Listed 
  event ItemListed(
		uint256 listingId,
		uint256 tokenId,
		address seller,
		uint256 price
	);

  /// @notice Event Delisted 
  event ItemDelisted(
		uint256 listingId,
		uint256 tokenId,
		address seller
	);

  /// @notice EventItem Sold 
  event ItemSold(
		uint256 listingId,
		uint256 tokenId,
		address seller,
		address buyer,
    uint256 price
	);

  /// @notice Event Fee changed
  event FeeChanged(
    uint256 oldFee,
    uint256 newFee,
    address changedBy
  );
 
  /// @notice Token constructor
  /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
  /// @param erc721Address Address of the NFT Contract.
  /// @param erc20Address Address of the Primary Token Contract.
  constructor(address erc721Address, address erc20Address) {
    erc721Contract = ERC721(erc721Address);
    erc20Contract = ERC20(erc20Address);
    fee = 0;
  }

  /// @notice add a Listing to the Marketplace
  /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
  /// @param tokenId NFT TokenId.
  /// @param price Price in NFTs.
  function addListing(uint256 tokenId, uint256 price) public nonReentrant
  {
    uint256 listingId = listingCount;
    listings[listingId] = Listing(
      msg.sender,
      true,
      tokenId,
      price
    );
    listingCount = listingCount.add(1);
    activeListingCount = activeListingCount.add(1);
    erc721Contract.transferFrom(
      msg.sender,
      address(this),
      tokenId);

    emit ItemListed(listingId, tokenId, msg.sender, price );   
  }

  /// @notice Remove a Listing from the Marketplace
  /// @dev Marks Listing as not active object and transfers the Token back
  /// @param listingId NFT Listing Id.
  function removeListing(uint256 listingId) public nonReentrant
  {
    require(listings[listingId].owner == msg.sender, "Must be owner");
    require(listings[listingId].isActive, "Must be active");
    listings[listingId].isActive = false;
    erc721Contract.transferFrom(
      address(this),
      msg.sender,
      listings[listingId].tokenId
    );
    activeListingCount = activeListingCount.sub(1);
    emit ItemDelisted(listingId, listings[listingId].tokenId, msg.sender );   
  }

  /// @notice Buys a listed NFT
  /// @dev Trabsfers both the ERC20 token (price) and the NFT.
  /// @param listingId NFT Listing Id.
  function buy(uint256 listingId) public nonReentrant
  {
    require(listings[listingId].isActive, "Must be active");
    listings[listingId].isActive = false;
    uint256 buyingFee = (fee * listings[listingId].price / 10000);
    erc20Contract.transferFrom(
      msg.sender,
      listings[listingId].owner,
      listings[listingId].price - buyingFee
    );
    if (buyingFee > 0 ) {
      erc20Contract.transferFrom(
        msg.sender,
       treasuryAddress,
        buyingFee
      );
    }
    erc721Contract.transferFrom(
      address(this),
      msg.sender,
      listings[listingId].tokenId
    );
    activeListingCount = activeListingCount.sub(1);
    emit ItemSold(
      listingId,
      listings[listingId].tokenId,
      listings[listingId].owner,
      msg.sender,
      listings[listingId].price
    );
  }

  /// @notice Sets a new Fee
  /// @param _fee new Fee.
  /// @param _treasuryAddress New treasury address.
  function setFee(uint256 _fee, address _treasuryAddress) public onlyOwner
  {
    fee = _fee;
    treasuryAddress = _treasuryAddress;
  }
}

