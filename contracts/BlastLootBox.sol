// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBlastLootbox.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

error NoZeroAddress();
error InvalidParams();
error NotOwner();
error NonExistToken();

/// @title Blast LootBox NFT
/// @dev BlastLootBox ERC721 token
contract BlastLootBox is
    IBlastLootbox,
    ERC721,
    ERC721URIStorage,
    ERC721Holder,
    AccessControl
{
    using Counters for Counters.Counter;

    struct LootBox {
        uint token0;
        uint token1;
        uint token2;
    }

    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    Counters.Counter private _tokenIdCounter;
    mapping(uint => LootBox) private lootboxDetails;
    mapping(uint => uint8) private tokenTypes;
    IBlastEquipmentNFT public blastEquipmentNFT;

    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    constructor(string memory name, string memory symbol, IBlastEquipmentNFT _blastEquipmentNFT) ERC721(name, symbol) {
        if (address(_blastEquipmentNFT) == address(0)) revert NoZeroAddress();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    /// @notice Creates a new token for `_to`. Its token ID will be automatically
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    /// _tokenType should be 1 or 2 (In case of 1, it's normal box. In case of 2, it's gw box)
    function safeMint(address[] calldata _to, string[] calldata _uri, LootBox[] calldata _eqtIds, uint8 _tokenType)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_to.length != _uri.length || _to.length != _eqtIds.length) revert InvalidParams();
        if (!(_tokenType == 1 || _tokenType == 2)) revert InvalidParams();

        for (uint i = 0; i < _to.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            lootboxDetails[tokenId] = _eqtIds[i];
            tokenTypes[tokenId] = _tokenType;
            _mint(_to[i], tokenId);
            _setTokenURI(tokenId, _uri[i]);
        }
    }

    function open(uint _tokenId) external {
        if (!_exists(_tokenId)) revert NonExistToken();
        if (_msgSender() != ownerOf(_tokenId)) revert NotOwner();

        _open(_tokenId, _msgSender());
    }

    function openTo(uint _tokenId, address _to) external onlyRole(GAME_ROLE) {
        if (!_exists(_tokenId)) revert NonExistToken();

        _open(_tokenId, _to);
    }

    function _open(uint _tokenId, address _to) internal {
        LootBox memory _eqtIds = lootboxDetails[_tokenId];
        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token0);
        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token1);
        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token2);

        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token0);
        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token1);
        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token2);

        _burn(_tokenId);
    }

    function getTokenType(uint _tokenId) external view override returns (uint8) {
        return tokenTypes[_tokenId];
    }

    /// @notice Unpauses all token transfers.
    /// @dev The caller must be the Owner (or have approval) of the Token.
    /// @param tokenId Token ID.
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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
        override(AccessControl, IERC165, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
