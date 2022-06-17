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
error NotActived();
error ReachedMaxLimit();
error NotEnough();
error NotAbleToAdd();
error NotAbleToBuy();
error InvalidMerkleProof();
error FailedToSendEther();

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
contract BlastLootboxSale is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_FACTOR = 100_00;

    bytes32 public merkleRoot;
    bytes32 public luckyMerkleRoot;

    address public treasury;
    PurchaseLimit private whitelistLimit;
    PurchaseLimit private luckyUserLimit;
    IERC20 public payTokenAddress;
    uint public price;

    mapping(address => mapping(uint8 => uint256)) private boughtCount;
    // mapping(address => bool) public whitelistedTokens;
    mapping(uint256 => bool) public tokenListed;
    // user => tokenType => count
    IBlastLootbox private lootboxContract;

    /// @notice Event Listed
    event LootboxListed(
        uint256 tokenId,
        uint256 price,
        address payTokenAddress
    );

    /// @notice Event Delisted
    event LootboxDelisted(uint256 tokenId);

    /// @notice EventItem Sold
    event LootboxSold(
        uint256 tokenId,
        address buyer,
        uint256 price
    );

    /// @notice Token constructor
    /// @dev Setup the blastlootbox contract
    /// @param lootboxAddress Address of the NFT Contract.
    constructor(IBlastLootbox lootboxAddress, uint _price, address _treasury, bytes32 _merkleRoot, bytes32 _luckyMerkleRoot) {
        if (address(lootboxAddress) == address(0)) revert NoZeroAddress();
        lootboxContract = lootboxAddress;
        merkleRoot = _merkleRoot;
        luckyMerkleRoot = _luckyMerkleRoot;
        price = _price;
        treasury = _treasury;

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
    /// @param _tokenIds NFT TokenIds.
    function addListing(uint256[] memory _tokenIds) public onlyOwner nonReentrant whenNotPaused {
        for (uint i = 0; i < _tokenIds.length; i++) {
            if (tokenListed[_tokenIds[i]] == true) revert NotAbleToAdd();
        }

        for (uint i = 0; i < _tokenIds.length; i++) {
            tokenListed[_tokenIds[i]] = true;
            lootboxContract.transferFrom(_msgSender(), address(this), _tokenIds[i]);

            emit LootboxListed(_tokenIds[i], price, address(payTokenAddress));
        }
    }

    /// @notice Remove a Listing from the Marketplace
    /// @dev Marks Listing as not active object and transfers the Token back
    /// @param _tokenIds NFT Token Ids.
    function removeListing(uint256[] memory _tokenIds)
        public
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        for (uint i = 0; i < _tokenIds.length; i++) {
            if (tokenListed[_tokenIds[i]] == false) revert NotActived();
        }

        for (uint i = 0; i < _tokenIds.length; i++) {
            tokenListed[_tokenIds[i]] = false;
            lootboxContract.transferFrom(address(this), _msgSender(), _tokenIds[i]);

            emit LootboxDelisted(_tokenIds[i]);
        }
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
        if (!tokenListed[_tokenId]) revert NotActived();

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
        tokenListed[_tokenId] = false;

        if (address(payTokenAddress) == address(0)) {
            if (msg.value != price) revert NotEnough();
            (bool sent, ) = payable(treasury).call{value: msg.value}("");
            if (!sent) revert FailedToSendEther();
        } else {
            payTokenAddress.safeTransferFrom(
                _msgSender(),
                treasury,
                price
            );
        }
        lootboxContract.transferFrom(address(this), _msgSender(), _tokenId);

        emit LootboxSold(_tokenId, _msgSender(), price);
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
    /// @param _price root of merkle Tree
    function setPrice(uint _price) public onlyOwner {
        price = _price;
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

    /// @notice Update Pay Token address
    /// @dev This function will update _luckyMerkleRoot
    /// @param _payTokenAddress root of merkle Tree
    function updatePayTokenAddress(IERC20 _payTokenAddress) public onlyOwner {
        payTokenAddress = _payTokenAddress;
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
