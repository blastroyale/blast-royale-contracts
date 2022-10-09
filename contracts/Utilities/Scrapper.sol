// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./../interfaces/IBlastEquipmentNFT.sol";
import "./../interfaces/ICraftSpiceToken.sol";

error NoZeroAddress();

contract Scrapper is AccessControl, ReentrancyGuard, Pausable {
    IBlastEquipmentNFT public blastEquipmentNFT;
    ICraftSpiceToken public csToken;

    uint256 public constant DECIMAL_FACTOR = 1000;

    uint256 public growthMultiplier = 1200;
    uint256[10] public csValuePerRarity = [
        100, 120, 144, 173, 208,
        250, 300, 360, 432, 518
    ];
    uint256[10] public csAdditiveValuePerAdjective = [
        20, 40, 70, 100, 100,
        200, 200, 350, 500, 500
    ];
    uint256[6] public gradeMultiplierPerGrade = [
        100, 110, 120, 140, 165, 200 // DECIMAL FACTOR = 100
    ];
    uint256 public csPercentagePerLevel = 25;

    event Scrapped(uint256 tokenId, address user, uint256 csAmount);

    constructor (IBlastEquipmentNFT _blastEquipmentNFT, ICraftSpiceToken _csToken) {
        if (
            address(_blastEquipmentNFT) == address(0) ||
            address(_csToken) == address(0)
        ) revert NoZeroAddress();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        csToken = _csToken;
    }

    function scrap(uint256 _tokenId) external {
        require(
            blastEquipmentNFT.ownerOf(_tokenId) == msg.sender,
            "Scrapper: Not owner of token"
        );
        blastEquipmentNFT.scrap(_tokenId);
        uint256 csAmount = getCSPrice(_tokenId);
        csToken.claim(_msgSender(), csAmount);

        emit Scrapped(_tokenId, _msgSender(), csAmount);
    }

    function getCSPrice(uint256 _tokenId) public view returns (uint256) {
        (, , uint8 adjective, uint8 rarity, uint8 grade) = blastEquipmentNFT.getStaticAttributes(_tokenId);
        (uint256 level, , , , ,) = blastEquipmentNFT.getAttributes(_tokenId);
        return ((csValuePerRarity[rarity] + csAdditiveValuePerAdjective[adjective]) + (csValuePerRarity[rarity] + csAdditiveValuePerAdjective[adjective]) * (level - 1) * csPercentagePerLevel / 1000) * gradeMultiplierPerGrade[grade] / 100 * 10 ** 18;
    }

    function setBlastEquipmentAddress(IBlastEquipmentNFT _blastEquipmentNFT)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastEquipmentNFT) != address(0), "NoZeroAddress");
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    function setCSTokenAddress(ICraftSpiceToken _csToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_csToken) != address(0), "NoZeroAddress");
        csToken = _csToken;
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