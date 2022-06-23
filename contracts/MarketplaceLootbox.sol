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

error NoZeroAddress();
error NoZeroPrice();
error NotOwner();
error NotActived();
error InvalidParam();
error ReachedMaxLimit();
error NotEnough();
error NotAbleToAdd();
error NotAbleToBuy();
error NotWhitelisted();
error InvalidMerkleProof();
error FailedToSendEther();
error StartTimeInvalid();

struct Listing {
    address owner;
    bool isActive;
    uint256 tokenId;
    uint256 price;
    IERC20 tokenAddress;
}

struct PurchaseLimit {
    uint gwbLimit;
    uint nbLimit;
}

/// @title Marketplace contract to trade Lootbox
/// @dev Based on OpenZeppelin Contracts.
contract MarketplaceLootbox is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_FACTOR = 100_00;

    bytes32 public merkleRoot;
    bytes32 public luckyMerkleRoot;

    uint public saleStartTimestamp;
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
    constructor(IBlastLootbox lootboxAddress, bytes32 _merkleRoot, bytes32 _luckyMerkleRoot) {
        if (address(lootboxAddress) == address(0)) revert NoZeroAddress();
        lootboxContract = lootboxAddress;
        merkleRoot = _merkleRoot;
        luckyMerkleRoot = _luckyMerkleRoot;

        whitelistLimit = PurchaseLimit({
            gwbLimit: 0,
            nbLimit: 1
        });
        luckyUserLimit = PurchaseLimit({
            gwbLimit: 1,
            nbLimit: 0
        });
    }

    /// @notice add a Listing to the Marketplace
    /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
    /// @param tokenId NFT TokenId.
    /// @param price Price in NFTs.
    function addListing(
        uint256 tokenId,
        uint256 price,
        IERC20 payTokenAddress
    ) public onlyOwner nonReentrant whenNotPaused {
        if (price == 0) revert NoZeroPrice();
        if (listings[tokenId].owner != address(0)) revert NotAbleToAdd();
        if (address(payTokenAddress) != address(0)) {
            if (!whitelistedTokens[address(payTokenAddress)])
                revert NotWhitelisted();
        }

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

    /// @notice Remove a Listing from the Marketplace
    /// @dev Marks Listing as not active object and transfers the Token back
    /// @param tokenId NFT Token Id.
    function removeListing(uint256 tokenId)
        public
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        if (listings[tokenId].owner != _msgSender()) revert NotOwner();
        if (!listings[tokenId].isActive) revert NotActived();
        listings[tokenId].isActive = false;
        lootboxContract.transferFrom(address(this), _msgSender(), tokenId);
        activeListingCount = activeListingCount - 1;
        emit LootboxDelisted(listings[tokenId].tokenId, _msgSender());
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
        if (tokenType == 0) revert NotAbleToBuy();
        if (!listings[_tokenId].isActive) revert NotActived();

        bool userWhitelisted = MerkleProof.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_msgSender())));
        bool isLuckyUser = MerkleProof.verify(_merkleProof, luckyMerkleRoot, keccak256(abi.encodePacked(_msgSender())));
        if (userWhitelisted) {
            if (boughtCount[_msgSender()][tokenType] >= getLimit(tokenType, true))
                revert ReachedMaxLimit();
        } else if (isLuckyUser) {
            if (boughtCount[_msgSender()][tokenType] >= getLimit(tokenType, false))
                revert ReachedMaxLimit();
        } else {
            revert InvalidMerkleProof();
        }

        boughtCount[_msgSender()][tokenType] += 1;
        listings[_tokenId].isActive = false;
        IERC20 payTokenAddress = listings[_tokenId].tokenAddress;

        if (address(payTokenAddress) == address(0)) {
            if (msg.value != listings[_tokenId].price) revert NotEnough();
            (bool sent, ) = payable(listings[_tokenId].owner).call{value: msg.value}("");
            if (!sent) revert FailedToSendEther();
        } else {
            require(msg.value == 0, "Not allowed to deposit native token");
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
        public
        view
        returns (uint256)
    {
        return boughtCount[_address][_tokenType];
    }

    /// @notice Get limitation value
    /// @dev This function will return limit value whether whitelisted or not and tokenType
    /// @param _tokenType Token Type (1 or 2), (1 is NB, 2 is GWB)
    /// @param _whitelist Whitelist or not
    function getLimit(uint _tokenType, bool _whitelist) internal view returns (uint) {
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
    function updateMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /// @notice Update LuckyMerkleRoot value
    /// @dev This function will update _luckyMerkleRoot
    /// @param _luckyMerkleRoot root of merkle Tree
    function updateLuckyMerkleRoot(bytes32 _luckyMerkleRoot) public onlyOwner {
        luckyMerkleRoot = _luckyMerkleRoot;
    }

    /// @notice Setting public sale start timestamp
    /// @dev This function will set saleStartTimestamp
    /// @param _timestamp sale Start Timestamp
    function startPublicSale(uint _timestamp) public onlyOwner {
        if (_timestamp <= block.timestamp) revert StartTimeInvalid();
        saleStartTimestamp = _timestamp;
    }

    /// @notice Set the limitation for whitelist users
    /// @dev This will set whitelist users limitation for GWB and NB
    /// @param _limit gwbLimit & nbLimit
    function setWhitelistPurchaseLimit(PurchaseLimit memory _limit) public onlyOwner {
        whitelistLimit = _limit;
    }

    /// @notice Set the limitation for whitelisted and lucky users
    /// @dev This will set non-whitelist users limitation for GWB and NB
    /// @param _limit gwbLimit & nbLimit
    function setNotWhitelistPurchaseLimit(PurchaseLimit memory _limit) public onlyOwner {
        luckyUserLimit = _limit;
    }

    /// @notice Set whitelist tokens for paying
    /// @dev This will create whitelisting of stable token for Lootbox trading
    /// @param _whitelist whitelist erc20 token array
    function setWhitelistTokens(address[] memory _whitelist) public onlyOwner {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            if (_whitelist[i] == address(0)) revert NoZeroAddress();
            whitelistedTokens[_whitelist[i]] = true;
        }

        emit WhitelistAdded(_whitelist);
    }

    /// @notice Remove whitelist tokens for paying
    /// @dev This will remove whitelisting of stable token for Lootbox trading
    /// @param _whitelist whitelist erc20 token array
    function removeWhitelistTokens(address[] memory _whitelist)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            if (_whitelist[i] == address(0)) revert NoZeroAddress();
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
