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

    struct StaticAttributes {
        uint8 maxLevel;
        uint8 maxDurability;
        uint8 adjective;
        uint8 rarity;
        uint8 grade;
    }

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
    uint256 public constant DECIMAL_FACTOR = 1000;

    uint256 private basePowerForCS = 2500; // 2.5
    uint256 private basePowerForBLST = 2025; // 2.025
    uint256 private basePriceForCS = 20000; // 20
    uint256 private basePriceForBLST = 50; // 0.05

    ERC20Burnable public csToken;
    IERC20 public blastToken;
    address public treasury;
    address public company;
    bool public isUsingMatic;

    Counters.Counter public _tokenIdCounter;
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
            durabilityRestored: 0,
            durability: 0,
            lastRepairTime: block.timestamp,
            repairCount: 0,
            replicationCount: 0
        });
        staticAttributes[tokenId] = StaticAttributes({
            maxLevel: 0,
            maxDurability: 96,
            adjective: 0,
            rarity: 0,
            grade: 4
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
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.level = _newLevel;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        emit AttributeUpdated(
            _tokenId,
            _newLevel,
            _durabilityPoint,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function extendDurability(
        uint256 _tokenId
    ) external override hasGameRole {
        VariableAttributes storage _attribute = attributes[_tokenId];
        _attribute.durabilityRestored += getDurabilityPoints(_attribute, _tokenId);
        _attribute.lastRepairTime = block.timestamp;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
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
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
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
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
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
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);
        return (
            _attribute.level,
            _durabilityPoint,
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
        uint256 _durabilityPoint = (block.timestamp - _attribute.lastRepairTime) / 1 weeks;
        return (_durabilityPoint >= _staticAttribute.maxDurability ? _staticAttribute.maxDurability : _durabilityPoint);
    }

    function repair(
        uint256 _tokenId
    ) external payable override {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Caller is not owner nor approved");
        VariableAttributes storage _attribute = attributes[_tokenId];
        uint256 durabilityPoints = getDurabilityPoints(_attribute, _tokenId);
        if ((_attribute.durabilityRestored + durabilityPoints) > 6) {
            uint256 blstPrice = getRepairPriceBLST(_tokenId);
            require(blstPrice > 0, "Price can't be zero");
            require(treasury != address(0), "Treasury is not set");
            require(company != address(0), "Company is not set");

            // Safe TransferFrom from msgSender to treasury
            if (isUsingMatic) {
                require(msg.value == blstPrice, "Repair:Invalid Matic Amount");
                (bool sent1, ) = payable(treasury).call{value: blstPrice / 4}("");
                require(sent1, "Failed to send treasuryAddress");
                (bool sent2, ) = payable(company).call{value: (blstPrice - blstPrice / 4)}("");
                require(sent2, "Failed to send companyAddress");
            } else {
                require(msg.value == 0, "Repair:Invalid Value");
                blastToken.safeTransferFrom(_msgSender(), treasury, blstPrice / 4);
                blastToken.safeTransferFrom(_msgSender(), company, (blstPrice - blstPrice / 4));
            }
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, "Price can't be zero");

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price);
        }

        _attribute.durabilityRestored += getDurabilityPoints(_attribute, _tokenId);
        _attribute.lastRepairTime = block.timestamp;
        uint256 _durabilityPoint = getDurabilityPoints(_attribute, _tokenId);

        emit AttributeUpdated(
            _tokenId,
            _attribute.level,
            _durabilityPoint,
            _attribute.repairCount,
            _attribute.replicationCount
        );
    }

    function getRepairPrice(uint256 _tokenId) public view returns (uint256) {
        VariableAttributes memory _attribute = attributes[_tokenId];
        uint256 temp = ((_attribute.durabilityRestored * 2 + 10) * getDurabilityPoints(_attribute, _tokenId)) * 10 ** 17;
        if (temp == 0) {
            return 0;
        }
        return PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp), basePowerForCS), DECIMAL_FACTOR)) * basePriceForCS / DECIMAL_FACTOR;
    }

    function getRepairPriceBLST(uint256 _tokenId) public view returns (uint256) {
        VariableAttributes memory _attribute = attributes[_tokenId];
        uint256 temp = ((_attribute.durabilityRestored + 1) * getDurabilityPoints(_attribute, _tokenId));
        if (temp == 0) {
            return 0;
        }
        return PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp * 10 ** 18), basePowerForBLST), DECIMAL_FACTOR)) * basePriceForBLST / DECIMAL_FACTOR;
    }

    /// @notice Set Base Power for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePower(uint256 _basePowerForCS, uint256 _basePowerForBLST) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePowerForCS > 0, "Can't be zero");
        require(_basePowerForBLST > 0, "Can't be zero");

        basePowerForCS = _basePowerForCS;
        basePowerForBLST = _basePowerForBLST;

        emit BasePowerUpdated(_basePowerForCS, _basePowerForBLST);
    }

    /// @notice Set Base Price for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePrice(uint256 _basePriceForCS, uint256 _basePriceForBLST) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePriceForCS > 0, "Can't be zero");
        require(_basePriceForBLST > 0, "Can't be zero");

        basePriceForCS = _basePriceForCS;
        basePriceForBLST = _basePriceForBLST;

        emit BasePriceUpdated(_basePriceForCS, _basePriceForBLST);
    }

    /// @notice Set Company address
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setCompanyAddress(address _company) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_company != address(0), "NoZeroAddress");

        company = _company;
    }

    /// @notice Set Treasury address
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setTreasuryAddress(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "NoZeroAddress");

        treasury = _treasury;
    }

    function setBlastTokenAddress(IERC20 _blastToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastToken) != address(0), "NoZeroAddress");
        blastToken = _blastToken;
    }

    function setCSTokenAddress(ERC20Burnable _csToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_csToken) != address(0), "NoZeroAddress");
        csToken = _csToken;
    }

    /// @notice Toggle isUsingMatic flag
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function toggleIsUsingMatic() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isUsingMatic = !isUsingMatic;
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
