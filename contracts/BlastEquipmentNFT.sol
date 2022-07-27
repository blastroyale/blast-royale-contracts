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
import "hardhat/console.sol";

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
        uint256 maxDurability;
        uint256 durabilityRestored;
        uint256 lastRepairTime;
        uint256 repairCount;
        uint256 replicationCount;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant REVEAL_ROLE = keccak256("REVEAL_ROLE");
    bytes32 public constant REPLICATOR_ROLE = keccak256("REPLICATOR_ROLE");

    ERC20Burnable public csToken;
    IERC20 public blastToken;
    address public treasury;
    Counters.Counter public _tokenIdCounter;
    mapping(uint256 => bytes32) public hashValue;
    mapping(uint256 => VariableAttributes) public attributes;
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
    constructor(string memory name, string memory symbol, ERC20Burnable _csToken, IERC20 _blastToken) ERC721(name, symbol) {
        require(address(_csToken) != address(0), "NoZeroAddress");
        require(address(_blastToken) != address(0), "NoZeroAddress");

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
        _setupRole(REVEAL_ROLE, _msgSender());
        _setupRole(REPLICATOR_ROLE, _msgSender());

        csToken = _csToken;
        blastToken = _blastToken;
    }

    /// @notice Creates a new token for `to`. Its token ID will be automatically
    /// @dev The caller must have the `MINTER_ROLE`.
    function safeMint(
        address _to,
        string[] calldata _uri,
        bytes32[] calldata _hash,
        string[] calldata _realUri
    ) external override onlyRole(MINTER_ROLE) {
        require(_to != address(0), "To address can't be zero");
        require(_uri.length == _hash.length, "Invalid params");
        require(_uri.length == _realUri.length, "Invalid params");

        for (uint256 i = 0; i < _uri.length; i = i + 1) {
            _safeMint(_to, _uri[i], _hash[i], _realUri[i]);
        }
    }

    function safeMintReplicator(
        address _to,
        string calldata _uri,
        bytes32 _hash,
        string calldata _realUri
    ) external override onlyRole(REPLICATOR_ROLE) returns (uint256) {
        require(_to != address(0), "To address can't be zero");

        return _safeMint(_to, _uri, _hash, _realUri);
    }

    function _safeMint(
        address _to,
        string memory _uri,
        bytes32 _hash,
        string memory _realUri
    ) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        hashValue[tokenId] = _hash;
        realTokenURI[tokenId] = _realUri;
        attributes[tokenId] = VariableAttributes({
            level: 1,
            maxDurability: 96,
            durabilityRestored: 0,
            lastRepairTime: block.timestamp,
            repairCount: 0,
            replicationCount: 0
        });
        _mint(_to, tokenId);
        _setTokenURI(tokenId, _uri);

        emit AttributeAdded(tokenId, 1, 0, 0, 0);

        return tokenId;
    }

    function revealRealTokenURI(uint256 _tokenId)
        external
        override
        onlyRole(REVEAL_ROLE)
    {
        _setTokenURI(_tokenId, realTokenURI[_tokenId]);
        emit PermanentURI(realTokenURI[_tokenId], _tokenId);
    }

    function setLevel(uint256 _tokenId, uint256 _newLevel)
        external
        override
        hasGameRole
    {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.level = _newLevel;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute);
        emit AttributeUpdated(
            _tokenId,
            _newLevel,
            _durabilityPoint,
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
        uint256 _durabilityPoint = getDurabilityPoints(_attribute);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _durabilityPoint,
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
        uint256 _durabilityPoint = getDurabilityPoints(_attribute);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _durabilityPoint,
            _attribute.repairCount,
            _newReplicationCount
        );
    }

    function getAttributes(uint256 _tokenId)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        VariableAttributes memory _attribute = attributes[_tokenId];
        uint256 _durabilityPoint = getDurabilityPoints(_attribute);
        return (
            _attribute.level,
            _durabilityPoint,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function getDurabilityPoints(VariableAttributes memory _attribute) internal view returns (uint256) {
        uint256 _durabilityPoint = (block.timestamp - _attribute.lastRepairTime) / 1 weeks;
        return (_durabilityPoint >= _attribute.maxDurability ? _attribute.maxDurability : _durabilityPoint);
    }

    function repair(
        uint256 _tokenId
    ) external override {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Caller is not owner nor approved");
        VariableAttributes storage _attribute = attributes[_tokenId];
        uint256 durabilityPoints = getDurabilityPoints(_attribute);
        if ((_attribute.durabilityRestored + durabilityPoints) > 6) {
            uint256 blstPrice = getRepairPriceBLST(_tokenId);
            require(blstPrice > 0, "Price can't be zero");
            require(treasury != address(0), "Treasury is not set");

            // Safe TransferFrom from msgSender to treasury
            blastToken.safeTransferFrom(_msgSender(), treasury, blstPrice);
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, "Price can't be zero");

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price * 10 ** 18);
        }
        
        _attribute.durabilityRestored += getDurabilityPoints(_attribute);
        _attribute.lastRepairTime = block.timestamp;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _durabilityPoint,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function getRepairPrice(uint256 tokenId) public view returns (uint256) {
        VariableAttributes memory _attribute = attributes[tokenId];
        return sqrt(((_attribute.durabilityRestored * 20 + 100) * getDurabilityPoints(_attribute)) ** 5) * 20 / 100000;
    }

    function getRepairPriceBLST(uint256 tokenId) public view returns (uint256) {
        VariableAttributes memory _attribute = attributes[tokenId];
        require(_attribute.durabilityRestored >= 6, "Durability must be at least 6");
        uint256 temp = ((_attribute.durabilityRestored + 1) * getDurabilityPoints(_attribute));
        if (temp == 0) {
            return 0;
        }
        return PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp * 10 ** 18), 2025), 1000)) * 5 / 100;
    }

    function sqrt(uint x) internal pure returns (uint y) {
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        uint z = (x + 1) / 2;
        y = x;
        while (z < y)
        {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Pauses all token transfers.
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setTreasuryAddress(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Can't be zero");

        treasury = _treasury;
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
