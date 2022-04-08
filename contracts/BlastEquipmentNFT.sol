// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Blast Equipment NFT
/// @dev BlastNFT ERC721 token
contract BlastEquipmentNFT is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Pausable,
    AccessControl
{
    using Counters for Counters.Counter;

    /// @dev Variable Attributes
    /// @notice These attributes would be nice to have on-chain because they affect the value of NFT and they are persistent when NFT changes hands.
    struct VariableAttributes {
        uint level;
        uint durabilityRemaining;
        uint repairCount;
        uint replicationCount;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    Counters.Counter private _tokenIdCounter;
    mapping(uint => bytes32) public hashValue;
    mapping(uint => VariableAttributes) public attributes;

    /// @notice Event Attribute Added
    event AttributeAdded(
		uint tokenId,
		uint level,
		uint durabilityRemaining,
        uint repairCount,
        uint replicationCount
	);

    /// @notice Event Attribute Updated
    event AttributeUpdated(
		uint tokenId,
		uint level,
		uint durabilityRemaining,
        uint repairCount,
        uint replicationCount
	);

    modifier hasGameRole() {
        require(hasRole(GAME_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccessControl: Missing role");
        _;
    }

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
    }

    /// @notice Creates a new token for `to`. Its token ID will be automatically
    /// @dev The caller must have the `MINTER_ROLE`.
    function safeMint(
        address _to,
        string[] memory _uri,
        bytes32[] memory _hash
    ) public onlyRole(MINTER_ROLE) {
        require(_uri.length == _hash.length, "Invalid params");

        for (uint256 i = 0; i < _uri.length; i = i + 1) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_to, tokenId);
            _setTokenURI(tokenId, _uri[i]);
            hashValue[tokenId] = _hash[i];
            attributes[tokenId] = VariableAttributes(1, 0, 0, 0);
            emit AttributeAdded(tokenId, 1, 0, 0, 0);
        }
    }

    function setLevel(uint _tokenId, uint _newLevel) public hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.level = _newLevel;
        emit AttributeUpdated(_tokenId, _newLevel, _attribute.durabilityRemaining, _attribute.repairCount, _attribute.replicationCount);
    }

    function setDurabilityRemaining(uint _tokenId, uint _newDurabilityRemaining) public hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.durabilityRemaining = _newDurabilityRemaining;
        emit AttributeUpdated(_tokenId, _attribute.level, _newDurabilityRemaining, _attribute.repairCount, _attribute.replicationCount);
    }

    function setRepairCount(uint _tokenId, uint _newRepairCount) public hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.repairCount = _newRepairCount;
        emit AttributeUpdated(_tokenId, _attribute.level, _attribute.durabilityRemaining, _newRepairCount, _attribute.replicationCount);
    }

    function setReplicationCount(uint _tokenId, uint _newReplicationCount) public hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.replicationCount = _newReplicationCount;
        emit AttributeUpdated(_tokenId, _attribute.level, _attribute.durabilityRemaining, _attribute.repairCount, _newReplicationCount);
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
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /// @notice Unpauses all token transfers.
    /// @dev The caller must be the Owner (or have approval) of the Token.
    /// @param tokenId Token ID.
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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
