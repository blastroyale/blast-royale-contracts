// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./IEquipmentNFT.sol";
import "./ICraftshipToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title Repair NFT
/// @dev Contract to Repair NFTs.
contract BlastFactory is Ownable, Pausable {

  event Treasury(address indexed treasury);
  event PricesChanged(uint256 bltRepairPrice, uint256 csRepairPrice, uint256 bltCraftPrice, uint256 csCraftPrice);
  event Repaired(address indexed owner, uint256 tokenId);
  event Crafted(address indexed owner, uint256 tokenId1, uint256 tokenId2);
  
  IEquipmentNFT private equipment;
  IERC20 private bltContract;
  ICraftshipToken private csContract;
  address private _treasury;
  uint256 private _bltRepairPrice;
  uint256 private _csRepairPrice;
  uint256 private _bltCraftPrice;
  uint256 private _csCraftPrice;
  uint public constant CRAFT_COUNT = 2;
  uint public constant MAX_CRAFT = 7;
  uint public constant REPAIR_COUNT = 3;
  uint public constant MAX_REPAIR = 5;
  uint public constant REPAIR_TS = 4;
  string private _baseURI;

  /// @notice Token constructor
  /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
  /// @param equipmentAddress of the NFT Contract.
  /// @param bltAddress Address of the Primary Token Contract : BLT.
  /// @param csAddress Address of the Secondary Token Contract : CS.
  /// @param treasury Address of the Treasury.
  /// @param baseURI Base URI for crafted items
  constructor(
    IEquipmentNFT equipmentAddress,
    IERC20 bltAddress,
    ICraftshipToken csAddress,
    address treasury,
    string memory baseURI
  ) {
    equipment = equipmentAddress;
    bltContract = bltAddress;
    csContract = csAddress;
    _treasury = treasury;
    _baseURI = baseURI;
  }

  /// @notice Repairs the NFT.
  /// @param tokenId Token ID.
  function repair(uint256 tokenId) external whenNotPaused {
    require(_msgSender() == equipment.ownerOf(tokenId), "Only the owner can repair");
    require(equipment.attributes(tokenId, REPAIR_COUNT) < MAX_REPAIR, "Max repair reached");
    if (_bltRepairPrice > 0) {
      bltContract.transferFrom(
        _msgSender(),
        _treasury,
        _bltRepairPrice
      );
    }
     if (_csRepairPrice > 0 ) {
      csContract.burnFrom(
        _msgSender(),
        _csRepairPrice
      );
    }
 
    equipment.incAttribute(tokenId, REPAIR_COUNT);
    equipment.tsAttribute(tokenId, REPAIR_TS);
    emit Repaired(_msgSender(), tokenId);
  }

  /// @notice Buys a listed NFT
  /// @dev Trabsfers both the ERC20 token (price) and the NFT.
  /// @param tokenId1 Token ID 1.
  /// @param tokenId2 Token ID 2.
  function craft(uint256 tokenId1, uint256 tokenId2) external whenNotPaused {
    require(equipment.ownerOf(tokenId1) == _msgSender(), "NFTs must be owned by the sender");
    require(equipment.ownerOf(tokenId2) == _msgSender(), "NFTs must be owned by the sender");
    require(equipment.attributes(tokenId1, CRAFT_COUNT) < MAX_CRAFT, "Max Craft reached");
    require(equipment.attributes(tokenId2, CRAFT_COUNT) < MAX_CRAFT, "Max Craft reached");
    if (_bltCraftPrice > 0) {
      bltContract.transferFrom(
        _msgSender(),
        _treasury,
        _bltCraftPrice
      );
    }
    if (_csCraftPrice > 0 ) {
      csContract.burnFrom(
        _msgSender(),
        _csCraftPrice
      );
    }
    equipment.incAttribute(tokenId1, CRAFT_COUNT);
    equipment.incAttribute(tokenId2, CRAFT_COUNT);
    equipment.safeMint(1, msg.sender, _baseURI);
    emit Crafted(_msgSender(), tokenId1, tokenId2);
  }

  /// @notice Sets the Cost in BLT
  /// @param bltRepairPrice Price to pay in BLT to Repair
  /// @param csRepairPrice Price to burn in CS to Repair
  /// @param bltCraftPrice Price to pay in BLT to Craft
  /// @param csCraftPrice Price to burn in CS to Craft
  function setPrices(
    uint256 bltRepairPrice,
    uint256 csRepairPrice,
    uint256 bltCraftPrice,
    uint256 csCraftPrice
  ) external onlyOwner {
    _bltRepairPrice = bltRepairPrice;
    _csRepairPrice = csRepairPrice;
    _bltCraftPrice = bltCraftPrice;
    _csCraftPrice = csCraftPrice;
    emit PricesChanged(_bltRepairPrice, _csRepairPrice, _bltCraftPrice, _csCraftPrice);
  }

  /// @notice Changes the Treasury address
  /// @param treasury Change Treasury Address
  function setTreasury(
    address treasury
  ) external onlyOwner {
    _treasury = treasury;
    emit Treasury(treasury);
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

