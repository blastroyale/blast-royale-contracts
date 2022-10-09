// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

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
    using SafeERC20 for IERC20;
    using PRBMathUD60x18 for uint256;

    /// @dev Variable Attributes
    /// @notice These attributes would be nice to have on-chain because they affect the value of NFT and they are persistent when NFT changes hands.
    struct VariableAttributes {
        uint256 level;
        uint256 durabilityRestored;
        uint256 durability;
        uint256 lastRepairTime;
        uint256 repairCount;
        uint256 replicationCount;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant REVEAL_ROLE = keccak256("REVEAL_ROLE");
    bytes32 public constant REPLICATOR_ROLE = keccak256("REPLICATOR_ROLE");

    Counters.Counter public _tokenIdCounter;
    uint256 public durabilityPointTimer = 1 weeks;
    mapping(uint256 => bytes32) public hashValue;
    mapping(uint256 => VariableAttributes) public attributes;
    mapping(uint256 => StaticAttributes) public staticAttributes;
    mapping(uint256 => string) private realTokenURI;

    modifier hasGameRole() {
        require(
            hasRole(GAME_ROLE, _msgSender()) ||
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) ||
            hasRole(REPLICATOR_ROLE, _msgSender()),
            "AccessControl: Missing role"
        );
        _;
    }

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
        _setupRole(REVEAL_ROLE, _msgSender());
        _setupRole(REPLICATOR_ROLE, _msgSender());
    }

    /// @notice Creates a new token for `to`. Its token ID will be automatically
    /// @dev The caller must have the `MINTER_ROLE`.
    function safeMint(
        address _to,
        string[] calldata _uri,
        bytes32[] calldata _hash,
        string[] calldata _realUri,
        StaticAttributes[] calldata _staticAttributes
    ) external onlyRole(MINTER_ROLE) {
        require(_to != address(0), "To address can't be zero");
        require(_uri.length == _hash.length, "Invalid params");
        require(_uri.length == _realUri.length, "Invalid params");

        for (uint256 i = 0; i < _uri.length; i = i + 1) {
            _safeMint(_to, _uri[i], _hash[i], _realUri[i], _staticAttributes[i]);
        }
    }

    function safeMintReplicator(
        address _to,
        string calldata _uri,
        bytes32 _hash,
        string calldata _realUri,
        StaticAttributes memory _staticAttributes
    ) external override onlyRole(REPLICATOR_ROLE) returns (uint256) {
        require(_to != address(0), "To address can't be zero");

        return _safeMint(_to, _uri, _hash, _realUri, _staticAttributes);
    }

    function _safeMint(
        address _to,
        string memory _uri,
        bytes32 _hash,
        string memory _realUri,
        StaticAttributes memory _staticAttributes
    ) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        hashValue[tokenId] = _hash;
        realTokenURI[tokenId] = _realUri;
        attributes[tokenId] = VariableAttributes({
            level: 1,
            durabilityRestored: 0,
            durability: 0,
            lastRepairTime: block.timestamp,
            repairCount: 0,
            replicationCount: 0
        });
        staticAttributes[tokenId] = _staticAttributes;

        _mint(_to, tokenId);
        _setTokenURI(tokenId, _uri);

        emit AttributeUpdated(tokenId, 1, 0, 0, block.timestamp, 0, 0);

        return tokenId;
    }

    function revealRealTokenURI(uint256 _tokenId)
        external
        override
        onlyRole(REVEAL_ROLE)
    {
        _setTokenURI(_tokenId, realTokenURI[_tokenId]);
        VariableAttributes storage _variableAttribute = attributes[_tokenId];
        _variableAttribute.lastRepairTime = block.timestamp;

        emit PermanentURI(realTokenURI[_tokenId], _tokenId);
    }

    function setRealTokenURI(uint256 _tokenId, string calldata _realUri)
        external
        override
        onlyRole(REVEAL_ROLE)
    {
        _setTokenURI(_tokenId, _realUri);
        emit PermanentURI(_realUri, _tokenId);
    }

    function setLevel(uint256 _tokenId, uint256 _newLevel)
        external
        override
        hasGameRole
    {
        StaticAttributes memory _staticAttribute = staticAttributes[_tokenId];
        require(_staticAttribute.maxLevel >= _newLevel, "Max level reached");

        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.level = _newLevel;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        emit AttributeUpdated(
            _tokenId,
            _newLevel,
            _attribute.durabilityRestored,
            _durabilityPoint,
            _attribute.lastRepairTime,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function setRepairCount(uint256 _tokenId, uint256 _newRepairCount)
        external
        override
        hasGameRole
    {
        VariableAttributes storage _attribute = attributes[_tokenId];

        _attribute.repairCount = _newRepairCount;
        _attribute.durabilityRestored += getDurabilityPoints(_attribute, _tokenId);
        _attribute.lastRepairTime = block.timestamp;

        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _attribute.durabilityRestored,
            _durabilityPoint,
            _attribute.lastRepairTime,
            _newRepairCount,
            _attribute.replicationCount
        );
    }

    function setReplicationCount(uint256 _tokenId, uint256 _newReplicationCount)
        external
        override
        hasGameRole
    {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.replicationCount = _newReplicationCount;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _attribute.durabilityRestored,
            _durabilityPoint,
            _attribute.lastRepairTime,
            _attribute.repairCount,
            _newReplicationCount
        );
    }

    function scrap(uint256 _tokenId) external override hasGameRole {
        _burn(_tokenId);
        delete attributes[_tokenId];
        delete staticAttributes[_tokenId];
        delete hashValue[_tokenId];
        delete realTokenURI[_tokenId];
    }

    function getAttributes(uint256 _tokenId)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        VariableAttributes memory _attribute = attributes[_tokenId];
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        return (
            _attribute.level,
            _attribute.durabilityRestored,
            _durabilityPoint,
            _attribute.lastRepairTime,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function getStaticAttributes(uint256 _tokenId)
        external
        view
        override
        returns (
            uint8,
            uint8,
            uint8,
            uint8,
            uint8
        )
    {
        StaticAttributes memory _attribute = staticAttributes[_tokenId];
        return (
            _attribute.maxLevel,
            _attribute.maxDurability,
            _attribute.adjective,
            _attribute.rarity,
            _attribute.grade
        );
    }

    function getDurabilityPoints(VariableAttributes memory _attribute, uint256 _tokenId) internal view returns (uint256) {
        StaticAttributes memory _staticAttribute = staticAttributes[_tokenId];
        uint256 _durabilityPoint = (block.timestamp - _attribute.lastRepairTime) / durabilityPointTimer;
        return (_durabilityPoint >= _staticAttribute.maxDurability ? _staticAttribute.maxDurability : _durabilityPoint);
    }

    function setStaticAttributes(uint256 _tokenId, StaticAttributes calldata _staticAttributes) external onlyRole(DEFAULT_ADMIN_ROLE) {
        staticAttributes[_tokenId] = _staticAttributes;
    }

    /// @notice Set the DurabilityPoint Timer
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setDurabilityPointTimer(uint256 _newTimer) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newTimer > 0, "Durability point timer can't be zero");
        durabilityPointTimer = _newTimer;
    }

    /// @notice Pauses all token transfers.
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all token transfers.
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
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
        super._burn(tokenId);
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
