// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

error NotOwner();
error NoZeroAddress();
error InvalidParams();

contract Replicator is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_FACTOR = 1000;

    // Calculation related variables
    struct Attributes {
        uint256 priceGrowth;
        uint16[10] pricePerRarity;
        uint8[10] pricePerAdjective;
        uint256 multiplierK;
        uint256 pricePerLevel;
    }

    uint256[10] public maxLevelPerRarity = [10, 12, 15, 17, 20, 22, 25, 27, 30, 35];
    uint16[5] public multiplierPerGrade = [1740, 1520, 1320, 1150, 1000];
    uint16 public gradeMultiplierK = 1149;
    Attributes public bltAttribute;
    Attributes public csAttribute;

    // Token related Addresses
    IBlastEquipmentNFT public blastEquipmentNFT;
    IERC20 public blastToken;
    ERC20Burnable public csToken;
    address private treasuryAddress;
    address private companyAddress;

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

        uint16[10] memory _bltPricePerRarity = [uint16(3), 4, 4, 5, 5, 6, 7, 7, 8, 9];
        uint8[10] memory _bltPricePerAdjective = [0, 0, 0, 1, 1, 2, 2, 3, 4, 4];
        uint16[10] memory _csPricePerRarity = [100, 144, 207, 297, 427, 613, 881, 1266, 1819, 2613];
        uint8[10] memory _csPricePerAdjective = [0, 0, 0, 1, 1, 2, 2, 3, 4, 4];

        bltAttribute = Attributes({
            priceGrowth: 1127,
            pricePerRarity: _bltPricePerRarity,
            pricePerAdjective: _bltPricePerAdjective,
            multiplierK: 1200,
            pricePerLevel: 500
        });
        csAttribute = Attributes({
            priceGrowth: 1437,
            pricePerRarity: _csPricePerRarity,
            pricePerAdjective: _csPricePerAdjective,
            multiplierK: 2250,
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

    function upgrade(uint256 _tokenId) external {

    }

    function getRequiredPrice(uint8 _tokenType) internal view returns (uint256) {
        uint8 rarity;
        uint8 adjective;
        uint8 grade;
        uint level;
        if (_tokenType == 0) {
            return ((bltAttribute.pricePerRarity[rarity] + bltAttribute.pricePerAdjective[adjective]) + (bltAttribute.pricePerRarity[rarity] + bltAttribute.pricePerAdjective[adjective]) * (level - 1) * bltAttribute.pricePerLevel) * multiplierPerGrade[grade] * 10 ** 18;
        }
        return 0;
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
