// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

struct Listing {
  address owner;
  bool isActive;
  uint256 tokenId;
  uint256 price;
  IERC20 tokenAddress;
}

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract Marketplace is ReentrancyGuard, Ownable, Pausable {
  using SafeERC20 for IERC20;

  uint public constant DECIMAL_FACTOR = 100_00;

  uint256 public listingCount;
  uint256 public activeListingCount;
  uint256 private fee1;
  address private treasury1;
  uint256 private fee2;
  address private treasury2;

  mapping (uint256 => Listing) public listings;
  IERC721 private erc721Contract;

  /// @notice Event Listed 
  event ItemListed(
		uint256 listingId,
		uint256 tokenId,
		address seller,
		uint256 price,
    address payTokenAddress
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
    uint256 price,
    uint256 fee1,
    uint256 fee2
	);

  /// @notice Event Fee changed
  event FeesChanged(
    uint256 fee1,
    address treasury1,
    uint256 fee2,
    address treasury2,
    address changedBy
  );
 
  /// @notice Token constructor
  /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
  /// @param erc721Address Address of the NFT Contract.
  constructor(IERC721 erc721Address) {
    require(address(erc721Address) != address(0));
    erc721Contract = erc721Address;
    fee1 = 0;
    fee2 = 0;
  }

  /// @notice add a Listing to the Marketplace
  /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
  /// @param tokenId NFT TokenId.
  /// @param price Price in NFTs.
  function addListing(uint256 tokenId, uint256 price, IERC20 payTokenAddress) public nonReentrant whenNotPaused
  {
    require(price > 0, "Price must be > 0");
    uint256 listingId = listingCount;
    listings[listingId] = Listing({
      owner: _msgSender(),
      isActive: true,
      tokenId: tokenId,
      price: price,
      tokenAddress: payTokenAddress
    });
    listingCount = listingCount + 1;
    activeListingCount = activeListingCount + 1;
    erc721Contract.transferFrom(
      _msgSender(),
      address(this),
      tokenId);

    emit ItemListed(listingId, tokenId, _msgSender(), price, address(payTokenAddress));   
  }

  /// @notice Remove a Listing from the Marketplace
  /// @dev Marks Listing as not active object and transfers the Token back
  /// @param listingId NFT Listing Id.
  function removeListing(uint256 listingId) public nonReentrant
  {
    require(listings[listingId].owner == _msgSender(), "Must be owner");
    require(listings[listingId].isActive, "Must be active");
    listings[listingId].isActive = false;
    erc721Contract.transferFrom(
      address(this),
      _msgSender(),
      listings[listingId].tokenId
    );
    activeListingCount = activeListingCount - 1;
    emit ItemDelisted(listingId, listings[listingId].tokenId, _msgSender() );   
  }

  /// @notice Buys a listed NFT
  /// @dev Trabsfers both the ERC20 token (price) and the NFT.
  /// @param listingId NFT Listing Id.
  function buy(uint256 listingId) public nonReentrant whenNotPaused
  {
    require(listings[listingId].isActive, "Must be active");
    listings[listingId].isActive = false;
    IERC20 payTokenAddress = listings[listingId].tokenAddress;
    uint256 buyingFee1 = (fee1 * listings[listingId].price / DECIMAL_FACTOR);
    if (buyingFee1 > 0 ) {
      payTokenAddress.safeTransferFrom(
        _msgSender(),
        treasury1,
        buyingFee1
      );
    }
    uint256 buyingFee2 = (fee2 * listings[listingId].price / DECIMAL_FACTOR);
    if (buyingFee2 > 0 ) {
      payTokenAddress.safeTransferFrom(
        _msgSender(),
        treasury2,
        buyingFee2
      );
    }
    erc721Contract.transferFrom(
      address(this),
      _msgSender(),
      listings[listingId].tokenId
    );
    payTokenAddress.safeTransferFrom(
      _msgSender(),
      listings[listingId].owner,
      listings[listingId].price - buyingFee1 - buyingFee2
    );
    activeListingCount = activeListingCount - 1;
    emit ItemSold(
      listingId,
      listings[listingId].tokenId,
      listings[listingId].owner,
      _msgSender(),
      listings[listingId].price,
      buyingFee1,
      buyingFee2
    );
  }

  /// @notice Sets a new Fee
  /// @param _fee1 new Fee1.
  /// @param _treasury1 New treasury1 address.
  /// @param _fee2 new Fee2.
  /// @param _treasury2 New treasury2 address.
  function setFee(uint256 _fee1, address _treasury1, uint256 _fee2, address _treasury2) public onlyOwner
  {
    require(_fee1 < DECIMAL_FACTOR);
    require(_fee2 < DECIMAL_FACTOR);
    require(_fee1 + _fee2 < DECIMAL_FACTOR);
    fee1 = _fee1;
    treasury1 = _treasury1;
    fee2 = _fee2;
    treasury2 = _treasury2;
    emit FeesChanged(
      fee1,
      treasury1,
      fee2,
      treasury2,
      _msgSender()
    );
  }

  // @notice Pauses/Unpauses the contract
  // @dev While paused, addListing, and buy are not allowed
  // @param stop whether to pause or unpause the contract.
  function pause(bool stop) external onlyOwner {
    if (stop) {
      _pause();
    } else {
      _unpause();
    }
  }
}

