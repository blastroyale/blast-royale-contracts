// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IBlastLootbox.sol";
import { Errors } from "./libraries/Errors.sol";

struct Listing {
    address owner;
    bool isActive;
    uint256 tokenId;
    uint256 price;
    IERC20 tokenAddress;
}

struct PurchaseLimit {
    uint256 gwbLimit;
    uint256 nbLimit;
}

/// @title Marketplace contract to trade Lootbox
/// @dev Based on OpenZeppelin Contracts.
contract MarketplaceLootbox is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public merkleRoot;
    bytes32 public luckyMerkleRoot;

    PurchaseLimit private whitelistLimit;
    PurchaseLimit private luckyUserLimit;
    uint256 public activeListingCount;

    mapping(address => bool) public whitelistedTokens;
    mapping(uint256 => Listing) public listings;
    // user => tokenType => count
    mapping(address => mapping(uint8 => uint256)) private boughtCount;
    IBlastLootbox private lootboxContract;

    /// @notice Event Listed
    event LootboxListed(
        uint256 tokenId,
        address seller,
        uint256 price,
        address payTokenAddress
    );

    /// @notice Event Delisted
    event LootboxDelisted(uint256 tokenId, address seller);

    /// @notice EventItem Sold
    event LootboxSold(
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price,
        bool whitelisted,
        bool isLucky
    );

    event WhitelistAdded(address[] whitelists);

    event WhitelistRemoved(address[] whitelists);

    /// @notice Token constructor
    /// @dev Setup the blastlootbox contract
    /// @param lootboxAddress Address of the NFT Contract.
    constructor(
        IBlastLootbox lootboxAddress,
        bytes32 _merkleRoot,
        bytes32 _luckyMerkleRoot
    ) {
        require(address(lootboxAddress) != address(0), Errors.NO_ZERO_ADDRESS);
        lootboxContract = lootboxAddress;
        merkleRoot = _merkleRoot;
        luckyMerkleRoot = _luckyMerkleRoot;

        whitelistLimit = PurchaseLimit({gwbLimit: 0, nbLimit: 1});
        luckyUserLimit = PurchaseLimit({gwbLimit: 1, nbLimit: 0});
    }

    /// @notice add a Listing to the Marketplace
    /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
    /// @param tokenIds NFT TokenId.
    /// @param price Price in NFTs.
    function addListing(
        uint256[] memory tokenIds,
        uint256 price,
        IERC20 payTokenAddress
    ) public onlyOwner nonReentrant whenNotPaused {
        require(price != 0, Errors.NO_ZERO_VALUE);
        if (address(payTokenAddress) != address(0)) {
            require(
                whitelistedTokens[address(payTokenAddress)],
                Errors.TOKEN_NOT_WHITELISTED
            );
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!listings[tokenIds[i]].isActive, Errors.LISTING_IS_NOT_ACTIVED);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            listings[tokenId] = Listing({
                owner: _msgSender(),
                isActive: true,
                tokenId: tokenId,
                price: price,
                tokenAddress: payTokenAddress
            });
            activeListingCount = activeListingCount + 1;
            lootboxContract.transferFrom(_msgSender(), address(this), tokenId);

            emit LootboxListed(
                tokenId,
                _msgSender(),
                price,
                address(payTokenAddress)
            );
        }
    }

    /// @notice Remove a Listing from the Marketplace
    /// @dev Marks Listing as not active object and transfers the Token back
    /// @param tokenId NFT Token Id.
    function removeListing(uint256 tokenId)
        public
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = listings[tokenId];
        require(listing.owner == _msgSender(), Errors.NOT_OWNER);
        require(listing.isActive, Errors.LISTING_IS_NOT_ACTIVED);
        listing.isActive = false;
        lootboxContract.transferFrom(address(this), _msgSender(), tokenId);
        activeListingCount = activeListingCount - 1;
        emit LootboxDelisted(listing.tokenId, _msgSender());
    }

    /// @notice Buys a listed NFT
    /// @dev Transfers both the ERC20 token (price) and the NFT.
    /// @param _tokenId NFT Token Id.
    /// @param _merkleProof MerkleProof value
    function buy(uint256 _tokenId, bytes32[] calldata _merkleProof)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        uint8 tokenType = lootboxContract.getTokenType(_tokenId);
        require(tokenType != 0, Errors.INVALID_PARAM);
        require(listings[_tokenId].isActive, Errors.LISTING_IS_NOT_ACTIVED);

        bool userWhitelisted = MerkleProof.verify(
            _merkleProof,
            merkleRoot,
            keccak256(abi.encodePacked(_msgSender()))
        );
        bool isLuckyUser = MerkleProof.verify(
            _merkleProof,
            luckyMerkleRoot,
            keccak256(abi.encodePacked(_msgSender()))
        );

        require(userWhitelisted || isLuckyUser, Errors.INVALID_MERKLE_PROOF);
        if (userWhitelisted) {
            require(boughtCount[_msgSender()][tokenType] < getLimit(tokenType, true), Errors.MAX_LIMIT_REACHED);
        } else if (isLuckyUser) {
            require(boughtCount[_msgSender()][tokenType] < getLimit(tokenType, false), Errors.MAX_LIMIT_REACHED);
        }

        boughtCount[_msgSender()][tokenType] += 1;
        listings[_tokenId].isActive = false;
        IERC20 payTokenAddress = listings[_tokenId].tokenAddress;

        if (address(payTokenAddress) == address(0)) {
            require(msg.value == listings[_tokenId].price, Errors.INVALID_AMOUNT);
            (bool sent, ) = payable(listings[_tokenId].owner).call{
                value: msg.value
            }("");
            require(sent, Errors.FAILED_TO_SEND_ETHER_USER);
        } else {
            require(msg.value == 0, Errors.INVALID_AMOUNT);
            payTokenAddress.safeTransferFrom(
                _msgSender(),
                listings[_tokenId].owner,
                listings[_tokenId].price
            );
        }
        lootboxContract.transferFrom(address(this), _msgSender(), _tokenId);

        activeListingCount = activeListingCount - 1;

        emit LootboxSold(
            listings[_tokenId].tokenId,
            listings[_tokenId].owner,
            _msgSender(),
            listings[_tokenId].price,
            userWhitelisted,
            isLuckyUser
        );
    }

    /// @notice Get purchased count
    /// @dev This function will return purchased count with tokenType
    /// @param _address owner Address
    /// @param _tokenType Token Type (1 or 2), (1 is NB, 2 is GWB)
    function getOwnedCount(address _address, uint8 _tokenType)
        external
        view
        returns (uint256)
    {
        return boughtCount[_address][_tokenType];
    }

    /// @notice Get limitation value
    /// @dev This function will return limit value whether whitelisted or not and tokenType
    /// @param _tokenType Token Type (1 or 2), (1 is NB, 2 is GWB)
    /// @param _whitelist Whitelist or not
    function getLimit(uint256 _tokenType, bool _whitelist)
        internal
        view
        returns (uint256)
    {
        if (_tokenType == 1) {
            if (_whitelist) {
                return whitelistLimit.nbLimit;
            } else {
                return luckyUserLimit.nbLimit;
            }
        } else if (_tokenType == 2) {
            if (_whitelist) {
                return whitelistLimit.gwbLimit;
            } else {
                return luckyUserLimit.gwbLimit;
            }
        }
        return 0;
    }

    /// @notice Update MerkleRoot value
    /// @dev This function will update merkleRoot
    /// @param _merkleRoot root of merkle Tree
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /// @notice Update LuckyMerkleRoot value
    /// @dev This function will update _luckyMerkleRoot
    /// @param _luckyMerkleRoot root of merkle Tree
    function updateLuckyMerkleRoot(bytes32 _luckyMerkleRoot)
        external
        onlyOwner
    {
        luckyMerkleRoot = _luckyMerkleRoot;
    }

    /// @notice Set the limitation for whitelist users
    /// @dev This will set whitelist users limitation for GWB and NB
    /// @param _limit gwbLimit & nbLimit
    function setWhitelistPurchaseLimit(PurchaseLimit memory _limit)
        external
        onlyOwner
    {
        whitelistLimit = _limit;
    }

    /// @notice Set the limitation for whitelisted and lucky users
    /// @dev This will set non-whitelist users limitation for GWB and NB
    /// @param _limit gwbLimit & nbLimit
    function setNotWhitelistPurchaseLimit(PurchaseLimit memory _limit)
        external
        onlyOwner
    {
        luckyUserLimit = _limit;
    }

    /// @notice Set whitelist tokens for paying
    /// @dev This will create whitelisting of stable token for Lootbox trading
    /// @param _whitelist whitelist erc20 token array
    function setWhitelistTokens(address[] memory _whitelist)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = true;
        }

        emit WhitelistAdded(_whitelist);
    }

    /// @notice Remove whitelist tokens for paying
    /// @dev This will remove whitelisting of stable token for Lootbox trading
    /// @param _whitelist whitelist erc20 token array
    function removeWhitelistTokens(address[] memory _whitelist)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = false;
        }

        emit WhitelistRemoved(_whitelist);
    }

    // @notice Pauses/Unpauses the contract
    // @dev While paused, addListing, and buy are not allowed
    // @param stop whether to pause or unpause the contract.
    function pause(bool stop) external onlyOwner {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}
