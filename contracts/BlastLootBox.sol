// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

/// @title Blast LootBox NFT
/// @dev BlastLootBox ERC721 token
contract BlastLootBox is
    ERC721,
    ERC721URIStorage,
    IERC721Receiver,
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
    IBlastEquipmentNFT public blastEquipmentNFT;

    event Received();

    /// @param name Name of the contract
    /// @param symbol Symbol of the contract
    constructor(string memory name, string memory symbol, IBlastEquipmentNFT _blastEquipmentNFT) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GAME_ROLE, _msgSender());
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    /// @notice Creates a new token for `_to`. Its token ID will be automatically
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function safeMint(address[] memory _to, string[] memory _uri, LootBox[] memory _eqtIds)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_to.length == _uri.length);
        require(_to.length == _eqtIds.length);
        for (uint i = 0; i < _to.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_to[i], tokenId);
            _setTokenURI(tokenId, _uri[i]);
            lootboxDetails[tokenId] = _eqtIds[i];
        }
    }

    function open(uint _tokenId) external {
        require(_exists(_tokenId), "nonexist token");
        require(_msgSender() == ownerOf(_tokenId));

        _open(_tokenId, _msgSender());
    }

    function openTo(uint _tokenId, address _to) external onlyRole(GAME_ROLE) {
        require(_exists(_tokenId), "nonexist token");
        require(_msgSender() == ownerOf(_tokenId));

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

    /// @notice Unpauses all token transfers.
    /// @dev The caller must be the Owner (or have approval) of the Token.
    /// @param tokenId Token ID.
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
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
        override(AccessControl, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        operator;
        from;
        tokenId;
        data;
        emit Received();
        return 0x150b7a02;
    }
}
