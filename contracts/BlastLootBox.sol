// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBlastLootbox.sol";
import "./interfaces/IBlastEquipmentNFT.sol";
import { Errors } from "./libraries/Errors.sol";

/// @title Blast LootBox NFT
/// @dev BlastLootBox ERC721 token
contract BlastLootBox is
    IBlastLootbox,
    ERC721,
    ERC721URIStorage,
    ERC721Holder,
    Pausable,
    AccessControl
{
    using Counters for Counters.Counter;

    struct LootBox {
        uint256 token0;
        uint256 token1;
        uint256 token2;
    }

    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    Counters.Counter public _tokenIdCounter;
    mapping(uint256 => LootBox) private lootboxDetails;
    mapping(uint256 => uint8) private tokenTypes;
    IBlastEquipmentNFT public blastEquipmentNFT;
    bool public openAvailable;

    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    constructor(
        string memory name,
        string memory symbol,
        IBlastEquipmentNFT _blastEquipmentNFT
    ) ERC721(name, symbol) {
        require(address(_blastEquipmentNFT) != address(0), Errors.NO_ZERO_ADDRESS);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    /// @notice Creates a new token for `_to`. Its token ID will be automatically
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    /// _tokenType should be 1 or 2 (In case of 1, it's normal box. In case of 2, it's gw box)
    function safeMint(
        address[] calldata _to,
        string[] calldata _uri,
        LootBox[] calldata _eqtIds,
        uint8 _tokenType
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_to.length == _uri.length && _to.length == _eqtIds.length, Errors.INVALID_PARAM);
        require(_tokenType == 1 || _tokenType == 2, Errors.INVALID_PARAM);

        for (uint256 i = 0; i < _to.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            lootboxDetails[tokenId] = _eqtIds[i];
            tokenTypes[tokenId] = _tokenType;
            _mint(_to[i], tokenId);
            _setTokenURI(tokenId, _uri[i]);
        }
    }

    function open(uint256 _tokenId) external {
        require(_exists(_tokenId), Errors.NOT_EXIST_TOKEN_ID);
        require(_msgSender() == ownerOf(_tokenId), Errors.NOT_OWNER);
        require(openAvailable, Errors.NOT_AVAILABLE_TO_OPEN);

        _open(_tokenId, _msgSender());
    }

    function openTo(uint256 _tokenId, address _to)
        external
        onlyRole(GAME_ROLE)
    {
        require(_exists(_tokenId), Errors.NOT_EXIST_TOKEN_ID);
        require(_to == ownerOf(_tokenId), Errors.NOT_OWNER);
        require(openAvailable, Errors.NOT_AVAILABLE_TO_OPEN);

        _open(_tokenId, _to);
    }

    function _open(uint256 _tokenId, address _to) internal {
        LootBox memory _eqtIds = lootboxDetails[_tokenId];

        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token0);
        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token1);
        blastEquipmentNFT.transferFrom(address(this), _to, _eqtIds.token2);

        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token0);
        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token1);
        blastEquipmentNFT.revealRealTokenURI(_eqtIds.token2);

        emit Open(_tokenId, _eqtIds.token0, _eqtIds.token1, _eqtIds.token2);
        _burn(_tokenId);
    }

    /// @notice Get Token Type. (GWB or NB)
    /// @dev Returned value should be 1 or 2
    /// @param _tokenId Token ID.
    function getTokenType(uint256 _tokenId)
        external
        view
        override
        returns (uint8)
    {
        return tokenTypes[_tokenId];
    }

    function setOpenAvailableStatus(bool _status)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        openAvailable = _status;
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

    // @notice Pauses/Unpauses the contract
    // @dev While paused, actions are not allowed
    // @param stop whether to pause or unpause the contract.
    function pause(bool stop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
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
