// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./../interfaces/IBlastEquipmentNFT.sol";
import "./Utility.sol";

contract Upgrader is Utility {
    using SafeERC20 for IERC20;

    event LevelUpgraded(uint256 tokenId, address owner, uint256 newLevel);

    // Calculation related variables
    struct Attributes {
        uint16[10] pricePerRarity;
        uint16[10] pricePerAdjective;
        uint256 pricePerLevel; // decimal factor 100000
    }

    uint256 public durabilityEffectDivider = 48;
    uint256[10] public maxLevelPerRarity = [
        10, 12, 15, 17, 20,
        22, 25, 27, 30, 35
    ];
    uint16[5] public multiplierPerGrade = [1740, 1520, 1320, 1150, 1000];
    Attributes public bltAttribute;
    Attributes public maticAttribute;
    Attributes public csAttribute;

    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress
    ) Utility(_blastEquipmentNFT, _blastToken, _csToken, _treasuryAddress, _companyAddress) {
        uint16[10] memory _bltPricePerRarity = [
            uint16(3), 4, 4, 5, 5,
            6, 7, 7, 8, 9
        ];
        uint16[10] memory _bltPricePerAdjective = [
            uint16(0), 0, 0, 1, 1,
            2, 2, 3, 4, 4
        ];
        uint16[10] memory _maticPricePerRarity = [
            uint16(30), 40, 40, 50, 50,
            60, 70, 70, 80, 90
        ];
        uint16[10] memory _maticPricePerAdjective = [
            uint16(0), 0, 0, 13, 13,
            27, 27, 40, 53, 53
        ];
        uint16[10] memory _csPricePerRarity = [
            100, 144, 207, 297, 427,
            613, 881, 1266, 1819, 2613
        ];
        uint16[10] memory _csPricePerAdjective = [
            0, 20, 50, 80, 80,
            180, 180, 330, 480, 480
        ];

        bltAttribute = Attributes({
            pricePerRarity: _bltPricePerRarity,
            pricePerAdjective: _bltPricePerAdjective,
            pricePerLevel: 500
        });
        maticAttribute = Attributes({
            pricePerRarity: _maticPricePerRarity, // DECIMAL 100
            pricePerAdjective: _maticPricePerAdjective, // DECIMAL 100
            pricePerLevel: 500
        });
        csAttribute = Attributes({
            pricePerRarity: _csPricePerRarity,
            pricePerAdjective: _csPricePerAdjective,
            pricePerLevel: 2500
        });
    }

    function setDurabilityEffectDivider(uint256 _newValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newValue > 0, Errors.NO_ZERO_VALUE);
        durabilityEffectDivider = _newValue;
    }

    function setMultiplierPerGrade(uint16[5] memory _multiplierPerGrade) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_multiplierPerGrade.length == 5, Errors.INVALID_PARAM);
        for (uint8 i = 0; i < 5; i++) {
            multiplierPerGrade[i] = _multiplierPerGrade[i];
        }
    }

    function upgrade(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(!isUsingMatic, Errors.USING_MATIC_NOW);
        require(_msgSender() == blastEquipmentNFT.ownerOf(_tokenId), Errors.NOT_OWNER);

        uint256 bltPrice = getRequiredPrice(0, _tokenId);
        uint256 csPrice = getRequiredPrice(1, _tokenId);
        (, , , , uint8 rarity, ) = blastEquipmentNFT.getStaticAttributes(_tokenId);
        (uint256 level, , , , ,) = blastEquipmentNFT.getAttributes(_tokenId);
        require(level != 0, Errors.INVALID_PARAM);
        require(level != maxLevelPerRarity[rarity], Errors.MAX_LEVEL_REACHED);
        require(bltPrice != 0 && csPrice != 0, Errors.INVALID_PARAM);

        csToken.burnFrom(_msgSender(), csPrice);
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

        blastEquipmentNFT.setLevel(_tokenId, level + 1);

        emit LevelUpgraded(_tokenId, _msgSender(), level + 1);
    }

    function upgradeUsingMatic(uint256 _tokenId) external payable nonReentrant whenNotPaused {
        require(isUsingMatic, Errors.NOT_USING_MATIC_NOW);
        require(_msgSender() == blastEquipmentNFT.ownerOf(_tokenId), Errors.NOT_OWNER);

        uint256 bltPrice = getRequiredPrice(0, _tokenId);
        uint256 csPrice = getRequiredPrice(1, _tokenId);
        (, , , , uint8 rarity, ) = blastEquipmentNFT.getStaticAttributes(_tokenId);
        (uint256 level, , , , ,) = blastEquipmentNFT.getAttributes(_tokenId);
        require(level != 0, Errors.INVALID_PARAM);
        require(level != maxLevelPerRarity[rarity], Errors.MAX_LEVEL_REACHED);
        require(bltPrice != 0 && csPrice != 0, Errors.INVALID_PARAM);

        csToken.burnFrom(_msgSender(), csPrice);
        require(msg.value == bltPrice, Errors.INVALID_AMOUNT);
        (bool sent1, ) = payable(treasuryAddress).call{value: bltPrice / 4}("");
        require(sent1, Errors.FAILED_TO_SEND_ETHER_TREASURY);
        (bool sent2, ) = payable(companyAddress).call{value: (bltPrice * 3) / 4}("");
        require(sent2, Errors.FAILED_TO_SEND_ETHER_COMPANY);

        blastEquipmentNFT.setLevel(_tokenId, level + 1);

        emit LevelUpgraded(_tokenId, _msgSender(), level + 1);
    }

    function getRequiredPrice(uint8 _tokenType, uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        (, uint8 maxDurability, ,uint8 adjective, uint8 rarity, uint8 grade) = blastEquipmentNFT
            .getStaticAttributes(_tokenId);
        (uint256 level, , , , ,) = blastEquipmentNFT.getAttributes(_tokenId);

        if (_tokenType == 0) {
            if (isUsingMatic) {
                return (maticAttribute.pricePerRarity[rarity] + maticAttribute.pricePerAdjective[adjective]) * (100000 + (level - 1) * maticAttribute.pricePerLevel) * multiplierPerGrade[grade] * 10 ** 10 / 100 * maxDurability / durabilityEffectDivider;
            }
            return (bltAttribute.pricePerRarity[rarity] + bltAttribute.pricePerAdjective[adjective]) * (100000 + (level - 1) * bltAttribute.pricePerLevel) * multiplierPerGrade[grade] * 10 ** 10 * maxDurability / durabilityEffectDivider;
        } else if (_tokenType == 1) {
            return (csAttribute.pricePerRarity[rarity] + csAttribute.pricePerAdjective[adjective]) * (100000 + (level - 1) * csAttribute.pricePerLevel) * multiplierPerGrade[grade] / DECIMAL_FACTOR / DECIMAL_FACTOR / 100 * 10 ** 18 * maxDurability / durabilityEffectDivider;
        } else {
            return 0;
        }
    }
}
