// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/// @title Blast Royale NFT
/// @dev BlastNFT ERC721 token
contract LootBox is
  ERC721,
  ERC721URIStorage,
  Pausable,
  AccessControl,
  ERC721Burnable,
  VRFConsumerBase {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  bytes32 internal keyHash;
  uint256 internal fee;
  uint256 public randomResult;

  /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
  /// @param name Name of the contract
  /// @param symbol Symbol of the contract
  constructor(
    string memory name,
    string memory symbol
  ) ERC721(name, symbol) 
    VRFConsumerBase(
      0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,
      0x326C977E6efc84E512bB9C30f76E30c160eD06FB 
    )
  {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
    fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
  }

  /**
   * Requests randomness
   */
  function getRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
    return requestRandomness(keyHash, fee);
  }

  /**
   * Callback function used by VRF Coordinator
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    randomResult = randomness;
  }
    
  /// @notice Creates a new token for `to`. Its token ID will be automatically
  /// @dev The caller must have the `MINTER_ROLE`.
  function safeMint(address to, string memory uri)
    public
    onlyRole(MINTER_ROLE)
  {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  /// @notice Pauses all token transfers.
  /// @dev The caller must have the `MINTER_ROLE`.
  function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  /// @notice Unpauses all token transfers.
  /// @dev The caller must have the `MINTER_ROLE`.
  function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
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
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
    _burn(tokenId);
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
