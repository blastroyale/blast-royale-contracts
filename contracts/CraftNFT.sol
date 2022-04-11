// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./IEquipmentNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract CraftNFT is Ownable, Pausable {

  IEquipmentNFT private equipment;
  IERC20 private erc20Contract;
  address private _treasury;
  uint256 private _craftPrice;
  uint public constant CRAFT_COUNT = 2;
  uint public constant MAX_CRAFT = 7;
  string private _baseURI;

  /// @notice Token constructor
  /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
  /// @param equipmentAddress of the NFT Contract.
  /// @param erc20Address Address of the Primary Token Contract.
  constructor(
    IEquipmentNFT equipmentAddress,
    IERC20 erc20Address,
    address treasury,
    uint256 craftPrice,
    string memory baseURI
  ) {
    equipment = equipmentAddress;
    erc20Contract = erc20Address;
    _treasury = treasury;
    _craftPrice = craftPrice;
    _baseURI = baseURI;
  }

  /// @notice Buys a listed NFT
  /// @dev Trabsfers both the ERC20 token (price) and the NFT.
  /// @param tokenId1 Token ID 1.
  /// @param tokenId2 Token ID 2.
  function craft(uint256 tokenId1, uint256 tokenId2) public whenNotPaused
  {
    require(equipment.ownerOf(tokenId1) == msg.sender, "NFTs must be owned by the sender");
    require(equipment.ownerOf(tokenId2) == msg.sender, "NFTs must be owned by the sender");
    require(equipment.attributes(tokenId1, CRAFT_COUNT) < MAX_CRAFT, "Max Craft reached");
    require(equipment.attributes(tokenId2, CRAFT_COUNT) < MAX_CRAFT, "Max Craft reached");
    if (_craftPrice > 0 ) {
      erc20Contract.transferFrom(
        _msgSender(),
        _treasury,
        _craftPrice
      );
    }
    equipment.incAttribute(tokenId1, CRAFT_COUNT);
    equipment.incAttribute(tokenId2, CRAFT_COUNT);
    equipment.safeMint(1, msg.sender, _baseURI);
  }

  /// @notice Sets the Cost in BLT
  function setPrice(uint256 craftPrice) external onlyOwner {
    _craftPrice = craftPrice;
  }

  /// @notice Pauses/Unpauses the contract
  /// @dev While paused, addListing, and buy are not allowed
  /// @param stop whether to pause or unpause the contract.
  function pause(bool stop) external onlyOwner {
    if (stop) {
      _pause();
    } else {
      _unpause();
    }
  }
}

