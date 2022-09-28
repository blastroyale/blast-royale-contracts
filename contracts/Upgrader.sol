// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBlastEquipmentNFT.sol";
import "hardhat/console.sol";

error NotOwner();
error NoZeroAddress();
error InvalidParams();
error MaxLevelReached();

contract Upgrader is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    event LevelUpgraded(uint256 tokenId, address owner, uint256 newLevel);

    uint256 public constant DECIMAL_FACTOR = 1000;

    // Calculation related variables
    struct Attributes {
        uint16[10] pricePerRarity;
        uint8[10] pricePerAdjective;
        uint256 pricePerLevel; // decimal factor 100000
    }

    uint256[10] public maxLevelPerRarity = [
        10,
        12,
        15,
        17,
        20,
        22,
        25,
        27,
        30,
        35
    ];
    uint16[5] public multiplierPerGrade = [1740, 1520, 1320, 1150, 1000];
    Attributes public bltAttribute;
    Attributes public csAttribute;

    // Token related Addresses
    IBlastEquipmentNFT public blastEquipmentNFT;
    IERC20 public blastToken;
    ERC20Burnable public csToken;
    address private treasuryAddress;
    address private companyAddress;
    bool public isUsingMatic;

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param _blastEquipmentNFT : address of EquipmentNFT contract
    /// @param _blastToken : address of Primary Token
    /// @param _csToken : address of Secondary Token
    /// @param _treasuryAddress : address of Treasury wallet
    /// @param _companyAddress : address of Company wallet
    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress
    ) {
        if (
            address(_blastEquipmentNFT) == address(0) ||
            address(_blastToken) == address(0) ||
            address(_csToken) == address(0) ||
            _treasuryAddress == address(0) ||
            _companyAddress == address(0)
        ) revert NoZeroAddress();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
        treasuryAddress = _treasuryAddress;
        companyAddress = _companyAddress;

        uint16[10] memory _bltPricePerRarity = [
            uint16(3),
            4,
            4,
            5,
            5,
            6,
            7,
            7,
            8,
            9
        ];
        uint8[10] memory _bltPricePerAdjective = [0, 0, 0, 1, 1, 2, 2, 3, 4, 4];
        uint16[10] memory _csPricePerRarity = [
            100,
            144,
            207,
            297,
            427,
            613,
            881,
            1266,
            1819,
            2613
        ];
        uint8[10] memory _csPricePerAdjective = [0, 0, 0, 1, 1, 2, 2, 3, 4, 4];

        bltAttribute = Attributes({
            pricePerRarity: _bltPricePerRarity,
            pricePerAdjective: _bltPricePerAdjective,
            pricePerLevel: 500
        });
        csAttribute = Attributes({
            pricePerRarity: _csPricePerRarity,
            pricePerAdjective: _csPricePerAdjective,
            pricePerLevel: 2500
        });
    }

    function setTreasuryAddress(address _treasury)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_treasury == address(0)) revert NoZeroAddress();
        treasuryAddress = _treasury;
    }

    function setCompanyAddress(address _company)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_company == address(0)) revert NoZeroAddress();
        companyAddress = _company;
    }

    function toggleIsUsingMatic() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isUsingMatic = !isUsingMatic;
    }

    function setBlastTokenAddress(IERC20 _blastToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (address(_blastToken) == address(0)) revert NoZeroAddress();
        blastToken = _blastToken;
    }

    function setCSTokenAddress(ERC20Burnable _csToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (address(_csToken) == address(0)) revert NoZeroAddress();
        csToken = _csToken;
    }

    function upgrade(uint256 _tokenId) external payable {
        if (_msgSender() != blastEquipmentNFT.ownerOf(_tokenId))
            revert NotOwner();

        uint256 bltPrice = getRequiredPrice(0, _tokenId);
        uint256 csPrice = getRequiredPrice(1, _tokenId);
        (, , , uint8 rarity, ) = blastEquipmentNFT.getStaticAttributes(_tokenId);
        (uint256 level, , , ) = blastEquipmentNFT.getAttributes(_tokenId);
        if (level == 0) revert InvalidParams();
        if (level == maxLevelPerRarity[rarity]) revert MaxLevelReached();

        if (bltPrice == 0 || csPrice == 0) revert InvalidParams();
        csToken.burnFrom(_msgSender(), csPrice);
        if (isUsingMatic) {
            require(msg.value == bltPrice, "Upgrader:Invalid Matic Amount");
            (bool sent1, ) = payable(treasuryAddress).call{value: bltPrice / 4}("");
            require(sent1, "Failed to send treasuryAddress");
            (bool sent2, ) = payable(companyAddress).call{value: (bltPrice * 3) / 4}("");
            require(sent2, "Failed to send companyAddress");
        } else {
            require(msg.value == 0, "Upgrader:Invalid Value");
            blastToken.safeTransferFrom(
                _msgSender(),
                treasuryAddress,
                bltPrice / 4
            );
            blastToken.safeTransferFrom(
                _msgSender(),
                companyAddress,
                (bltPrice * 3) / 4
            );
        }

        blastEquipmentNFT.setLevel(_tokenId, level + 1);

        emit LevelUpgraded(_tokenId, _msgSender(), level + 1);
    }

    function getRequiredPrice(uint8 _tokenType, uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        (, , uint8 adjective, uint8 rarity, uint8 grade) = blastEquipmentNFT
            .getStaticAttributes(_tokenId);
        (uint256 level, , , ) = blastEquipmentNFT.getAttributes(_tokenId);

        if (_tokenType == 0) {
            return (bltAttribute.pricePerRarity[rarity] + bltAttribute.pricePerAdjective[adjective]) * (100000 + (level - 1) * bltAttribute.pricePerLevel) * multiplierPerGrade[grade] * 10 ** 10;
        } else if (_tokenType == 1) {
            return (csAttribute.pricePerRarity[rarity] + csAttribute.pricePerAdjective[adjective]) * (100000 + (level - 1) * csAttribute.pricePerLevel) * multiplierPerGrade[grade] / DECIMAL_FACTOR / DECIMAL_FACTOR / 100 * 10 ** 18;
        } else {
            revert InvalidParams();
        }
    }

    // @notice Pauses/Unpauses the contract
    // @dev While paused, addListing, and buy are not allowed
    // @param stop whether to pause or unpause the contract.
    function pause(bool stop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}
