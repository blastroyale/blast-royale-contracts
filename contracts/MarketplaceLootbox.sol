// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBlastLootbox.sol";

error NoZeroAddress();
error NoZeroPrice();
error NotOwner();
error NotActived();
error InvalidParam();
error ReachedMaxLimit();
error NotEnough();
error NotAbleToAdd();
error NotAbleToBuy();

struct Listing {
  address owner;
  bool isActive;
  uint256 tokenId;
  uint256 price;
  IERC20 tokenAddress;
}

/// @title Marketplace contract to trade Lootbox
/// @dev Based on OpenZeppelin Contracts.
contract MarketplaceLootbox is ReentrancyGuard, Ownable, Pausable {
  using SafeERC20 for IERC20;

  uint public constant DECIMAL_FACTOR = 100_00;
  uint public constant MAX_PURCHASE_COUNT = 1;

  uint256 public listingCount;
  uint256 public activeListingCount;

  mapping (uint256 => Listing) public listings;
  // user => tokenType => count
  mapping (address => mapping (uint8 => uint)) private ownedCount;
  IBlastLootbox private lootboxContract;

  /// @notice Event Listed 
  event LootboxListed(
		uint256 tokenId,
		address seller,
		uint256 price,
    address payTokenAddress
	);

  /// @notice Event Delisted 
  event LootboxDelisted(
		uint256 tokenId,
		address seller
	);

  /// @notice EventItem Sold 
  event LootboxSold(
		uint256 tokenId,
		address seller,
		address buyer,
    uint256 price
	);
 
  /// @notice Token constructor
  /// @dev Setup the blastlootbox contract
  /// @param lootboxAddress Address of the NFT Contract.
  constructor(IBlastLootbox lootboxAddress) {
    if (address(lootboxAddress) == address(0)) revert NoZeroAddress();
    lootboxContract = lootboxAddress;
  }

  /// @notice add a Listing to the Marketplace
  /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
  /// @param tokenId NFT TokenId.
  /// @param price Price in NFTs.
  function addListing(uint256 tokenId, uint256 price, IERC20 payTokenAddress) public onlyOwner nonReentrant whenNotPaused
  {
    if (price == 0) revert NoZeroPrice();
    if (listings[tokenId].owner != address(0)) revert NotAbleToAdd();
    listings[tokenId] = Listing({
      owner: _msgSender(),
      isActive: true,
      tokenId: tokenId,
      price: price,
      tokenAddress: payTokenAddress
    });
    activeListingCount = activeListingCount + 1;
    lootboxContract.transferFrom(
      _msgSender(),
      address(this),
      tokenId
    );

    emit LootboxListed(tokenId, _msgSender(), price, address(payTokenAddress));   
  }

  /// @notice Remove a Listing from the Marketplace
  /// @dev Marks Listing as not active object and transfers the Token back
  /// @param tokenId NFT Token Id.
  function removeListing(uint256 tokenId) public onlyOwner nonReentrant whenNotPaused
  {
    if (listings[tokenId].owner != _msgSender()) revert NotOwner();
    if (!listings[tokenId].isActive) revert NotActived();
    listings[tokenId].isActive = false;
    lootboxContract.transferFrom(
      address(this),
      _msgSender(),
      tokenId
    );
    activeListingCount = activeListingCount - 1;
    emit LootboxDelisted(listings[tokenId].tokenId, _msgSender());   
  }

  /// @notice Buys a listed NFT
  /// @dev Transfers both the ERC20 token (price) and the NFT.
  /// @param _tokenId NFT Token Id.
  function buy(uint _tokenId) public payable nonReentrant whenNotPaused
  {
    uint8 tokenType = lootboxContract.getTokenType(_tokenId);
    if (tokenType == 0) revert NotAbleToBuy();
    if (ownedCount[_msgSender()][tokenType] >= MAX_PURCHASE_COUNT) revert ReachedMaxLimit();
    if (!listings[_tokenId].isActive) revert NotActived();

    ownedCount[_msgSender()][tokenType] += 1;

    listings[_tokenId].isActive = false;
    IERC20 payTokenAddress = listings[_tokenId].tokenAddress;

    if (address(payTokenAddress) == address(0)) {
      if (msg.value < listings[_tokenId].price) revert NotEnough();
      (bool sent, ) = payable(owner()).call{value: msg.value}("");
      require(sent, "Failed to send Ether");
    } else {
      payTokenAddress.safeTransferFrom(
        _msgSender(),
        listings[_tokenId].owner,
        listings[_tokenId].price
      );
    }
    lootboxContract.transferFrom(address(this), _msgSender(), _tokenId);
    
    activeListingCount = activeListingCount - 1;
    
    emit LootboxSold(
      listings[_tokenId].tokenId,
      listings[_tokenId].owner,
      _msgSender(),
      listings[_tokenId].price
    );
  }

  function getOwnedCount(address _address, uint8 _tokenType) public view returns (uint) {
    return ownedCount[_address][_tokenType];
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

