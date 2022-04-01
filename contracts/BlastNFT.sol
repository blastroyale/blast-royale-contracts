// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Blast Royale NFT
/// @dev BlastNFT ERC721 token
contract BlastNFT is ERC721, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  mapping(uint256 => bytes32) public seeds;

  /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
  /// @param name Name of the contract
  /// @param symbol Symbol of the contract
  constructor(
    string memory name,
    string memory symbol
  ) ERC721(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
  }

  /// @notice Creates a new token for `to`. Its token ID will be automatically
  /// @dev The caller must have the `MINTER_ROLE`.
  function safeMint(address to, string[] memory uri, bytes32[] memory _seeds)
    public
    onlyRole(MINTER_ROLE)
  {
    for (uint256 i = 0; i < uri.length; i = i + 1) {
      uint256 tokenId = _tokenIdCounter.current();
      _tokenIdCounter.increment();
      _safeMint(to, tokenId);
      _setTokenURI(tokenId, uri[i]);
      seeds[tokenId] = _seeds[i];
    }
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
    require(_isApprovedOrOwner(_msgSender(), tokenId), "Not the owner");
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
