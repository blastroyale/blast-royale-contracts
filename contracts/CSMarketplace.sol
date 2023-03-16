// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {Errors} from "./libraries/Errors.sol";

struct Listing {
    address owner;
    bool isActive;
    uint256 amount;
    uint256 price;
    IERC20 tokenAddress;
}

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract CSMarketplace is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_FACTOR = 100_00;

    uint256 public listingCount;
    uint256 public activeListingCount;
    uint256 public fee1;
    address public treasury1;
    uint256 public fee2;
    address public treasury2;
    bool public isUsingMatic;

    mapping(address => bool) public whitelistedTokens;
    mapping(uint256 => Listing) public listings;
    IERC20 public erc20Contract;

    /// @notice Event Listed
    event CSListed(
        uint256 listingId,
        uint256 amount,
        address seller,
        uint256 price,
        address payTokenAddress
    );

    /// @notice Event Delisted
    event CSDelisted(uint256 listingId, uint256 amount, address seller);

    /// @notice EventItem Sold
    event CSSold(
        uint256 listingId,
        uint256 amount,
        address seller,
        address buyer,
        uint256 price,
        uint256 fee1,
        uint256 fee2
    );

    /// @notice Event Fee changed
    event FeesChanged(
        uint256 fee1,
        address treasury1,
        uint256 fee2,
        address treasury2,
        address changedBy
    );

    event WhitelistAdded(address[] whitelists);

    event WhitelistRemoved(address[] whitelists);

    /// @notice Token constructor
    /// @dev Setup the two contracts it will interact with : CS token and ERC20
    /// @param erc20Address Address of the CS Contract.
    constructor(IERC20 erc20Address) {
        require(address(erc20Address) != address(0), Errors.NO_ZERO_ADDRESS);
        erc20Contract = erc20Address;
    }

    /// @notice add a Listing to the Marketplace
    /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
    /// @param amount amount of CS.
    /// @param price Price of CS.
    function addListing(
        uint256 amount,
        uint256 price,
        IERC20 payTokenAddress
    ) public nonReentrant whenNotPaused {
        require(price != 0, Errors.NO_ZERO_VALUE);
        if (address(payTokenAddress) != address(0)) {
            require(
                whitelistedTokens[address(payTokenAddress)],
                Errors.TOKEN_NOT_WHITELISTED
            );
        }

        uint256 listingId = listingCount;
        listings[listingId] = Listing({
            owner: _msgSender(),
            isActive: true,
            amount: amount,
            price: price,
            tokenAddress: payTokenAddress
        });
        listingCount = listingCount + 1;
        activeListingCount = activeListingCount + 1;
        erc20Contract.safeTransferFrom(_msgSender(), address(this), amount);

        emit CSListed(
            listingId,
            amount,
            _msgSender(),
            price,
            address(payTokenAddress)
        );
    }

    /// @notice Remove a Listing from the Marketplace
    /// @dev Marks Listing as not active object and transfers the Token back
    /// @param listingId CS Listing Id.
    function removeListing(uint256 listingId) public nonReentrant {
        Listing storage listing = listings[listingId];
        require(
            listing.owner == _msgSender() || owner() == _msgSender(),
            Errors.NOT_OWNER
        );
        require(listing.isActive, Errors.LISTING_IS_NOT_ACTIVED);
        listing.isActive = false;
        erc20Contract.transfer(listing.owner, listing.amount);
        activeListingCount = activeListingCount - 1;
        emit CSDelisted(listingId, listing.amount, listing.owner);
    }

    /// @notice Buys an amount of listed CS
    /// @dev Trabsfers both the ERC20 token (price) and CS.
    /// @param listingId CS Listing Id.
    function buy(uint256 listingId) public payable nonReentrant whenNotPaused {
        require(listings[listingId].isActive, Errors.LISTING_IS_NOT_ACTIVED);

        listings[listingId].isActive = false;
        IERC20 payTokenAddress = listings[listingId].tokenAddress;
        uint256 listedPrice = listings[listingId].price;
        uint256 buyingFee1 = ((fee1 * listedPrice) / DECIMAL_FACTOR);
        uint256 buyingFee2 = ((fee2 * listedPrice) / DECIMAL_FACTOR);

        if (isUsingMatic) {
            require(msg.value == listedPrice, Errors.INVALID_AMOUNT);
            if (buyingFee1 > 0) {
                (bool sent1, ) = payable(treasury1).call{value: buyingFee1}("");
                require(sent1, Errors.FAILED_TO_SEND_ETHER_TREASURY);
            }
            if (buyingFee2 > 0) {
                (bool sent2, ) = payable(treasury2).call{value: buyingFee2}("");
                require(sent2, Errors.FAILED_TO_SEND_ETHER_COMPANY);
            }
            (bool sent, ) = payable(listings[listingId].owner).call{
                value: listedPrice - buyingFee1 - buyingFee2
            }("");
            require(sent, Errors.FAILED_TO_SEND_ETHER_USER);
        } else {
            require(msg.value == 0, Errors.INVALID_AMOUNT);
            if (buyingFee1 > 0) {
                payTokenAddress.safeTransferFrom(
                    _msgSender(),
                    treasury1,
                    buyingFee1
                );
            }
            if (buyingFee2 > 0) {
                payTokenAddress.safeTransferFrom(
                    _msgSender(),
                    treasury2,
                    buyingFee2
                );
            }
            payTokenAddress.safeTransferFrom(
                _msgSender(),
                listings[listingId].owner,
                listedPrice - buyingFee1 - buyingFee2
            );
        }
        erc20Contract.transfer(_msgSender(), listings[listingId].amount);
        activeListingCount = activeListingCount - 1;

        emit CSSold(
            listingId,
            listings[listingId].amount,
            listings[listingId].owner,
            _msgSender(),
            listedPrice,
            buyingFee1,
            buyingFee2
        );
    }

    /// @notice Sets a new Fee
    /// @param _fee1 new Fee1.
    /// @param _treasury1 New treasury1 address.
    /// @param _fee2 new Fee2.
    /// @param _treasury2 New treasury2 address.
    function setFee(
        uint256 _fee1,
        address _treasury1,
        uint256 _fee2,
        address _treasury2
    ) public onlyOwner {
        require(_fee1 + _fee2 < DECIMAL_FACTOR, Errors.INVALID_PARAM);
        require(_treasury1 != address(0), Errors.NO_ZERO_ADDRESS);
        require(_treasury2 != address(0), Errors.NO_ZERO_ADDRESS);

        fee1 = _fee1;
        treasury1 = _treasury1;
        fee2 = _fee2;
        treasury2 = _treasury2;

        emit FeesChanged(fee1, treasury1, fee2, treasury2, _msgSender());
    }

    function setWhitelistTokens(address[] calldata _whitelist)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = true;
        }

        emit WhitelistAdded(_whitelist);
    }

    function removeWhitelistTokens(address[] calldata _whitelist)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = false;
        }

        emit WhitelistRemoved(_whitelist);
    }

    function flipIsUsingMatic() external onlyOwner {
        isUsingMatic = !isUsingMatic;
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