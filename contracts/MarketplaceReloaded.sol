// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./libraries/ContractTypeChecker.sol";
import {Errors} from "./libraries/Errors.sol";

struct Listing {
    address owner;
    bool isActive;
    uint256[] tokenIds;
    uint256 price;
    IERC20 tokenAddress;
    address nftAddress;
    uint256[] amounts;
}

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract MarketplaceReloaded is
    ReentrancyGuard,
    Ownable,
    Pausable,
    ERC1155Holder,
    ContractTypeChecker
{
    using SafeERC20 for IERC20;

    uint public constant DECIMAL_FACTOR = 100_00;

    uint256 public listingCount;
    uint256 public activeListingCount;
    uint256 public fee1;
    address public treasury1;
    uint256 public fee2;
    address public treasury2;
    bool public isUsingMatic;

    mapping(address => bool) public whitelistedTokens;
    mapping(uint256 => Listing) public listings;

    mapping(address => bool) public whitelistedNFTContracts;

    modifier onlyWhitelistedNFT(address tokenContract) {
        require(
            whitelistedNFTContracts[tokenContract],
            "Token contract is not whitelisted"
        );
        _;
    }

    /// @notice Event Listed
    event ItemListed(
        uint256 listingId,
        uint256[] tokenId,
        address seller,
        uint256 price,
        address payTokenAddress,
        address tokenContract
    );

    /// @notice Event Delisted
    event ItemDelisted(uint256 listingId, uint256[] tokenIds, address seller);

    /// @notice EventItem Sold
    event ItemSold(
        uint256 listingId,
        uint256[] tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 fee1,
        uint256 fee2,
        address nftAddress
    );

    /// @notice Event Fee changed
    event FeesChanged(
        uint256 fee1,
        address treasury1,
        uint256 fee2,
        address treasury2,
        address changedBy
    );

    event PriceChanged(uint256 listingId, uint256 price, address tokenAddress);

    event WhitelistAdded(address[] whitelists);

    event WhitelistRemoved(address[] whitelists);

    constructor() {}

    /// @notice add a Listing to the Marketplace
    /// @dev Creates a new entry for a Listing object and transfers the Token to the contract
    /// @param tokenIds NFT TokenId.
    /// @param price Price in NFTs.
    function addListing(
        uint256[] calldata tokenIds,
        uint256 price,
        IERC20 payTokenAddress,
        address tokenContract,
        uint256[] calldata amounts
    ) public nonReentrant whenNotPaused onlyWhitelistedNFT(tokenContract) {
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
            tokenIds: tokenIds,
            price: price,
            tokenAddress: payTokenAddress,
            nftAddress: tokenContract,
            amounts: amounts
        });
        listingCount = listingCount + 1;
        activeListingCount = activeListingCount + 1;
        if (isERC721OrERC1155(tokenContract) == 1155) {
            require(
                tokenIds.length == amounts.length,
                "lenghts of tokenIds and amounts don't match"
            );
            IERC1155(tokenContract).safeBatchTransferFrom(
                msg.sender,
                address(this),
                tokenIds,
                amounts,
                "0x00"
            );
        } else if (isERC721OrERC1155(tokenContract) == 721) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                IERC721(tokenContract).transferFrom(
                    _msgSender(),
                    address(this),
                    tokenIds[i]
                );
            }
        }

        emit ItemListed(
            listingId,
            tokenIds,
            _msgSender(),
            price,
            address(payTokenAddress),
            tokenContract
        );
    }

    function addBatchListing(
        uint256[] calldata tokenIds,
        uint256[] calldata price,
        IERC20 payTokenAddress,
        address tokenContract,
        uint256[] calldata amounts
    ) public nonReentrant whenNotPaused onlyWhitelistedNFT(tokenContract) {
        if (address(payTokenAddress) != address(0)) {
            require(
                whitelistedTokens[address(payTokenAddress)],
                Errors.TOKEN_NOT_WHITELISTED
            );
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(price[i] != 0, Errors.NO_ZERO_VALUE);
            uint256 listingId = listingCount;
            require(
                tokenIds.length == price.length &&
                    tokenIds.length == amounts.length,
                "Token ids, price and amounts length are different"
            );

            uint256[] memory tokenId = new uint256[](1);
            tokenId[0] = tokenIds[i];
            uint256[] memory _amount = new uint256[](1);
            _amount[0] = amounts[i];
            listings[listingId] = Listing({
                owner: _msgSender(),
                isActive: true,
                tokenIds: tokenId,
                price: price[i],
                tokenAddress: payTokenAddress,
                nftAddress: tokenContract,
                amounts: _amount
            });
            listingCount = listingCount + 1;
            activeListingCount = activeListingCount + 1;

            emit ItemListed(
                listingId,
                tokenId,
                _msgSender(),
                price[i],
                address(payTokenAddress),
                tokenContract
            );
        }

        if (isERC721OrERC1155(tokenContract) == 1155) {
            IERC1155(tokenContract).safeBatchTransferFrom(
                msg.sender,
                address(this),
                tokenIds,
                amounts,
                "0x00"
            );
        } else if (isERC721OrERC1155(tokenContract) == 721) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                IERC721(tokenContract).transferFrom(
                    _msgSender(),
                    address(this),
                    tokenIds[i]
                );
            }
        }
    }

    /// @notice Remove a Listing from the Marketplace
    /// @dev Marks Listing as not active object and transfers the Token back
    /// @param listingIds NFT Listing Id.
    function removeListing(uint256[] calldata listingIds) public nonReentrant {
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            require(
                listing.owner == _msgSender() || owner() == _msgSender(),
                Errors.NOT_OWNER
            );
            require(listing.isActive, Errors.LISTING_IS_NOT_ACTIVED);
            listing.isActive = false;
            if (isERC721OrERC1155(listing.nftAddress) == 1155) {
                IERC1155(listing.nftAddress).safeBatchTransferFrom(
                    address(this),
                    msg.sender,
                    listing.tokenIds,
                    listing.amounts,
                    "0x00"
                );
            } else if (isERC721OrERC1155(listing.nftAddress) == 721) {
                for (uint256 j = 0; j < listing.tokenIds.length; j++) {
                    IERC721(listing.nftAddress).transferFrom(
                        address(this),
                        listing.owner,
                        listing.tokenIds[j]
                    );
                }
            }

            activeListingCount = activeListingCount - 1;
            emit ItemDelisted(listingIds[i], listing.tokenIds, listing.owner);
        }
    }

    /// @notice Buys a listed NFT
    /// @dev Trabsfers both the ERC20 token (price) and the NFT.
    /// @param listingId NFT Listing Id.
    function buy(uint256 listingId) public payable nonReentrant whenNotPaused {
        require(listings[listingId].isActive, Errors.LISTING_IS_NOT_ACTIVED);
        Listing storage listing = listings[listingId];
        listing.isActive = false;
        IERC20 payTokenAddress = listing.tokenAddress;
        uint listedPrice = listing.price;
        uint256 buyingFee1 = ((fee1 * listedPrice) / DECIMAL_FACTOR);
        uint256 buyingFee2 = ((fee2 * listedPrice) / DECIMAL_FACTOR);

        if (isUsingMatic) {
            require(msg.value == listedPrice, Errors.INVALID_AMOUNT);
            require(
                address(listing.tokenAddress) == address(0),
                "Token not supported"
            );
            if (buyingFee1 > 0) {
                (bool sent1, ) = payable(treasury1).call{value: buyingFee1}("");
                require(sent1, Errors.FAILED_TO_SEND_ETHER_TREASURY);
            }
            if (buyingFee2 > 0) {
                (bool sent2, ) = payable(treasury2).call{value: buyingFee2}("");
                require(sent2, Errors.FAILED_TO_SEND_ETHER_COMPANY);
            }
            (bool sent, ) = payable(listing.owner).call{
                value: listedPrice - buyingFee1 - buyingFee2
            }("");
            require(sent, Errors.FAILED_TO_SEND_ETHER_USER);
        } else {
            require(msg.value == 0, Errors.INVALID_AMOUNT);
            require(
                whitelistedTokens[address(listing.tokenAddress)],
                "Token not supported"
            );
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
                listing.owner,
                listedPrice - buyingFee1 - buyingFee2
            );
        }

        if (isERC721OrERC1155(listing.nftAddress) == 1155) {
            IERC1155(listing.nftAddress).safeBatchTransferFrom(
                address(this),
                msg.sender,
                listing.tokenIds,
                listing.amounts,
                "0x00"
            );
        } else if (isERC721OrERC1155(listing.nftAddress) == 721) {
            for (uint256 i = 0; i < listings[listingId].tokenIds.length; i++) {
                IERC721(listing.nftAddress).transferFrom(
                    address(this),
                    _msgSender(),
                    listings[listingId].tokenIds[i]
                );
            }
        }

        activeListingCount = activeListingCount - 1;

        emit ItemSold(
            listingId,
            listings[listingId].tokenIds,
            listings[listingId].owner,
            _msgSender(),
            listedPrice,
            buyingFee1,
            buyingFee2,
            address(listings[listingId].nftAddress)
        );
    }

    /// @notice Set price of a Listing from the Marketplace
    /// @param listingId NFT Listing Id.
    /// @param price NFT Listing price.
    function setPrice(
        uint256 listingId,
        uint256 price,
        IERC20 tokenAddress
    ) public nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.owner == _msgSender(), Errors.NOT_OWNER);
        require(listing.isActive, Errors.LISTING_IS_NOT_ACTIVED);
        require(
            whitelistedTokens[address(tokenAddress)],
            "Token not supported"
        );

        listing.price = price;
        listing.tokenAddress = tokenAddress;

        emit PriceChanged(listingId, price, address(tokenAddress));
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

    function setWhitelistTokens(
        address[] calldata _whitelist
    ) external onlyOwner {
        for (uint i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = true;
        }

        emit WhitelistAdded(_whitelist);
    }

    function removeWhitelistTokens(
        address[] calldata _whitelist
    ) external onlyOwner {
        for (uint i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedTokens[_whitelist[i]] = false;
        }

        emit WhitelistRemoved(_whitelist);
    }

    function setWhitelistNFTContracts(
        address[] calldata _whitelist
    ) external onlyOwner {
        for (uint i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedNFTContracts[_whitelist[i]] = true;
        }

        emit WhitelistAdded(_whitelist);
    }

    function removeWhitelistNFTContracts(
        address[] calldata _whitelist
    ) external onlyOwner {
        for (uint i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), Errors.NO_ZERO_ADDRESS);
            whitelistedNFTContracts[_whitelist[i]] = false;
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
