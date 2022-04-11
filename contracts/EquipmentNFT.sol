// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Blast Royale NFT
/// @dev BlastNFT ERC721 token
contract EquipmentNFT is ERC721, ERC721URIStorage, ERC721Burnable, Pausable, AccessControl {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;

  uint public constant URI_SET = 0;
  uint public constant LEVEL = 1;
  uint public constant CRAFT_COUNT = 2;
  uint public constant REPAIR_COUNT = 3;
  uint public constant REPAIR_TS = 4;
  uint public constant MAX_REPAIR = 5;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

  mapping(uint256 => mapping(uint => uint)) public attributes;

  /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
  /// @param name Name of the contract
  /// @param symbol Symbol of the contract
  /// @param minter Adress -> MINTER Role
  /// @param game Adress -> GAME Role
  constructor(
    string memory name,
    string memory symbol,
    address minter,
    address game
  ) ERC721(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, minter);
    _setupRole(GAME_ROLE, game);
  }

  /// @notice Creates a new token for `to`. Its token ID will be automatically
  /// @dev The caller must have the `MINTER_ROLE`.
  /// @param number The number of NFTs to Mint
  /// @param to The address receiving the NFTs
  /// @param defaultURI the default URI when the NFT is not set yet.
  function safeMint(uint256 number, address to, string memory defaultURI)
    external
    onlyRole(MINTER_ROLE)
  {
    for (uint256 i = 0; i < number ; i = i + 1) {
      uint256 tokenId = _tokenIdCounter.current();
      _tokenIdCounter.increment();
      _safeMint(to, tokenId);
      _setTokenURI(tokenId, defaultURI);
      attributes[tokenId][URI_SET] = 0;
      attributes[tokenId][LEVEL] = 1;
      attributes[tokenId][REPAIR_COUNT] = 0;
      attributes[tokenId][REPAIR_TS] = block.timestamp;
      attributes[tokenId][CRAFT_COUNT] = 0;
    }
  }

  /// @notice Returns the TokenURI.
  /// @param tokenId Token ID.
  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  /// @notice Sets the Token URI
  /// @dev The Caller must have the `GAME_ROLE`. It can be only called once per NFT.
  /// @param tokenIds Array of tokenIds to be Set.
  /// @param newURIs Array of URIs to be Set.
  function setTokenURI(uint256[] memory tokenIds, string[] memory newURIs) 
    external
    onlyRole(GAME_ROLE)
  {
    for (uint256 i = 0; i < tokenIds.length; i = i + 1) {
      require(attributes[tokenIds[i]][URI_SET] == 0, "URI Can only be set once");
      attributes[tokenIds[i]][URI_SET] = 1;
      _setTokenURI(tokenIds[i], newURIs[i]);
    }
  }

  /// @notice Repairs the NFT.
  /// @param tokenId Token ID.
  function repair(uint256 tokenId) external {
    require(_msgSender() == ownerOf(tokenId), "Only the owner can repair");
    require(attributes[tokenId][REPAIR_COUNT] < MAX_REPAIR, "Max repair reached");
    attributes[tokenId][REPAIR_COUNT]++;
    attributes[tokenId][REPAIR_TS] = block.timestamp;
  }

  /// @notice Sets the Attributes for one NFT
  /// @dev The Caller must have the `DEFAULT_ADMIN_ROLE`.
  /// @param tokenId Token ID
  /// @param index Index of the Attribute
  /// @param value Value of the Attribute
  function setAttribute(uint256 tokenId, uint index, uint value)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    attributes[tokenId][index] = value;
  }
 
  /// @notice Sets the Attributes for one NFT
  /// @dev The Caller must have the `DEFAULT_ADMIN_ROLE`.
  /// @param tokenId Token ID
  /// @param index Index of the Attribute
  function incAttribute(uint256 tokenId, uint index)
    external
    onlyRole(GAME_ROLE)
  {
    attributes[tokenId][index]++;
  }

  /// @notice Pauses all token transfers.
  /// @dev The caller must have the `MINTER_ROLE`.
  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  /// @notice Unpauses all token transfers.
  /// @dev The caller must have the `MINTER_ROLE`.
  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  function _beforeTokenTransfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual whenNotPaused override {
      super._beforeTokenTransfer(from, to, tokenId);
  }

  /// @notice Unpauses all token transfers.
  /// @dev The caller must be the Owner (or have approval) of the Token.
  /// @param tokenId Token ID.
  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "Not the owner");
    _burn(tokenId);
  }

 /// @dev See {IERC165-supportsInterface}.
  /// @param interfaceId Interface ID.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC721)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
