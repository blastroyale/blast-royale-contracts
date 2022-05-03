// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IBlastEquipmentNFT.sol";
import "hardhat/console.sol";

error NotOwner();
error NotExist();
error NotReadyToMorph();
error InvalidParams();

/// @title Blast Equipment NFT
/// @dev BlastNFT ERC721 token
contract BlastEquipmentNFT is
    ERC721,
    IBlastEquipmentNFT,
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

    struct Parents {
        uint f1;
        uint f2;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant REVEAL_ROLE = keccak256("REVEAL_ROLE");

    Counters.Counter public _tokenIdCounter;
    mapping(uint => bytes32) public hashValue;
    mapping(uint => VariableAttributes) public attributes;
    mapping(uint => string) private realTokenURI;
    // Replication Related Variables
    mapping(uint => bool) public isReplicating;
    mapping(uint => uint64) private morphLimitTimestamp;
    mapping(uint => Parents) public parentsInfo;

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
        bytes32[] memory _hash,
        string[] memory _realUri
    ) external override onlyRole(MINTER_ROLE) {
        if(_uri.length != _hash.length) revert InvalidParams();
        if(_uri.length != _realUri.length) revert InvalidParams();

        for (uint256 i = 0; i < _uri.length; i = i + 1) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_to, tokenId);
            _setTokenURI(tokenId, _uri[i]);
            hashValue[tokenId] = _hash[i];
            realTokenURI[tokenId] = _realUri[i];
            attributes[tokenId] = VariableAttributes(1, 0, 0, 0);
            emit AttributeAdded(tokenId, 1, 0, 0, 0);
        }
    }

    function revealRealTokenURI(uint _tokenId) external override onlyRole(REVEAL_ROLE) {
        _setTokenURI(_tokenId, realTokenURI[_tokenId]);
        emit PermanentURI(realTokenURI[_tokenId], _tokenId);
    }

    function setLevel(uint _tokenId, uint _newLevel) external override hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.level = _newLevel;
        emit AttributeUpdated(_tokenId, _newLevel, _attribute.durabilityRemaining, _attribute.repairCount, _attribute.replicationCount);
    }

    function setDurabilityRemaining(uint _tokenId, uint _newDurabilityRemaining) external override hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.durabilityRemaining = _newDurabilityRemaining;
        emit AttributeUpdated(_tokenId, _attribute.level, _newDurabilityRemaining, _attribute.repairCount, _attribute.replicationCount);
    }

    function setRepairCount(uint _tokenId, uint _newRepairCount) external override hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.repairCount = _newRepairCount;
        emit AttributeUpdated(_tokenId, _attribute.level, _attribute.durabilityRemaining, _newRepairCount, _attribute.replicationCount);
    }

    function setReplicationCount(uint _tokenId, uint _newReplicationCount) external override hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.replicationCount = _newReplicationCount;
        emit AttributeUpdated(_tokenId, _attribute.level, _attribute.durabilityRemaining, _attribute.repairCount, _newReplicationCount);
    }

    function getAttributes(uint _tokenId) external view returns (uint, uint, uint, uint) {
        VariableAttributes memory _attribute = attributes[_tokenId];
        return (_attribute.level, _attribute.durabilityRemaining, _attribute.repairCount, _attribute.replicationCount);
    }

    function isReadyToMorph(uint _tokenId) public view returns (bool) {
        return isReplicating[_tokenId] && (morphLimitTimestamp[_tokenId] <= uint64(block.timestamp));
    }

    function replicate(address _to, string memory _uri, string memory _realUri, bytes32 _hash, uint _f1, uint _f2) external override hasGameRole {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
        hashValue[tokenId] = _hash;
        realTokenURI[tokenId] = _realUri;
        attributes[tokenId] = VariableAttributes(1, 0, 0, 0);

        parentsInfo[tokenId] = Parents(_f1, _f2);
        isReplicating[tokenId] = true;
        morphLimitTimestamp[tokenId] = uint64(block.timestamp + 5 days);

        emit AttributeAdded(tokenId, 1, 0, 0, 0);
    }

    function morphTo(uint _tokenId) external {
        if (_exists(_tokenId) == false) revert NotExist();
        if (ownerOf(_tokenId) != _msgSender()) revert NotOwner();
        if (isReadyToMorph(_tokenId) != true) revert NotReadyToMorph();

        isReplicating[_tokenId] = false;
        _setTokenURI(_tokenId, realTokenURI[_tokenId]);
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
        override(AccessControl, ERC721, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
