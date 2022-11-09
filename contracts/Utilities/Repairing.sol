// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@prb/math/contracts/PRBMathUD60x18.sol";
import "./../interfaces/IBlastEquipmentNFT.sol";
import "./Utility.sol";

contract Repairing is Utility {
    using SafeERC20 for IERC20;
    using PRBMathUD60x18 for uint256;

    uint256 private basePowerForCS = 2500; // 2.5
    uint256 private basePowerForBLST = 2025; // 2.025
    uint256 private basePriceForCS = 20000; // 20
    uint256 private basePriceForBLST = 50; // 0.05
    uint16 private significanceK = 200; // DECIMAL_FACTOR 100

    /// @notice Event Base Power Updated
    event BasePowerUpdated(uint256 _basePowerCS, uint256 _basePowerBLST);

    /// @notice Event Base Price Updated
    event BasePriceUpdated(uint256 _basePriceCS, uint256 _basePriceBLST);

    event Repaired(uint256 tokenId, uint256 repairTimestamp);

    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress
    ) Utility(_blastEquipmentNFT, _blastToken, _csToken, _treasuryAddress, _companyAddress) {
    }

    function getRepairPrice(uint256 _tokenId) public view returns (uint256) {
        (, uint256 durabilityRestored, uint256 durabilityPoint, , , ) = blastEquipmentNFT.getAttributes(_tokenId);
        uint256 temp = ((durabilityRestored * significanceK + DECIMAL_FACTOR) * durabilityPoint) * 10 ** 18 / DECIMAL_FACTOR;
        if (temp == 0) {
            return 0;
        }
        return PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp), basePowerForCS), DECIMAL_FACTOR)) * basePriceForCS / DECIMAL_FACTOR;
    }

    function getRepairPriceBLST(uint256 _tokenId) public view returns (uint256) {
        (, uint256 durabilityRestored, uint256 durabilityPoint, , , ) = blastEquipmentNFT.getAttributes(_tokenId);
        if ((durabilityRestored + durabilityPoint) > 6) {
            uint256 temp = ((durabilityRestored + 1) * durabilityPoint);
            if (temp == 0) {
                return 0;
            }
            uint256 priceInBLST = PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp * 10 ** 18), basePowerForBLST), DECIMAL_FACTOR)) * basePriceForBLST / DECIMAL_FACTOR;
            if (isUsingMatic) {
                int maticPrice = getLatestPrice();
                return maticPrice > 0 ? priceInBLST * uint256(maticPrice) / 10 ** 8 : priceInBLST;
            }
            return priceInBLST;
        }
        return 0;
    }

    /// @notice Set Base Power for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePower(uint256 _basePowerForCS, uint256 _basePowerForBLST) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePowerForCS > 0, Errors.NO_ZERO_VALUE);
        require(_basePowerForBLST > 0, Errors.NO_ZERO_VALUE);

        basePowerForCS = _basePowerForCS;
        basePowerForBLST = _basePowerForBLST;

        emit BasePowerUpdated(_basePowerForCS, _basePowerForBLST);
    }

    /// @notice Set significanceK value
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setSignificanceK(uint16 _significanceK) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_significanceK > 0, Errors.NO_ZERO_VALUE);
        significanceK = _significanceK;
    }

    /// @notice Set Base Price for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePrice(uint256 _basePriceForCS, uint256 _basePriceForBLST) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePriceForCS > 0, Errors.NO_ZERO_VALUE);
        require(_basePriceForBLST > 0, Errors.NO_ZERO_VALUE);

        basePriceForCS = _basePriceForCS;
        basePriceForBLST = _basePriceForBLST;

        emit BasePriceUpdated(_basePriceForCS, _basePriceForBLST);
    }

    function repair(
        uint256 _tokenId
    ) external nonReentrant whenNotPaused {
        require(!isUsingMatic, Errors.USING_MATIC_NOW);
        require(blastEquipmentNFT.ownerOf(_tokenId) == msg.sender, Errors.NOT_OWNER);
        (, uint256 durabilityRestored, uint256 durabilityPoints, , uint256 repairCount, ) = blastEquipmentNFT.getAttributes(_tokenId);
        if ((durabilityRestored + durabilityPoints) > 6) {
            uint256 blstPrice = getRepairPriceBLST(_tokenId);
            require(blstPrice > 0, Errors.INVALID_AMOUNT);

            // Safe TransferFrom from msgSender to treasury
            blastToken.safeTransferFrom(_msgSender(), treasuryAddress, blstPrice / 4);
            blastToken.safeTransferFrom(_msgSender(), companyAddress, (blstPrice - blstPrice / 4));
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, Errors.INVALID_AMOUNT);

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price);
        }

        blastEquipmentNFT.setRepairCount(_tokenId, repairCount + 1);

        emit Repaired(_tokenId, block.timestamp);
    }

    function repairUsingMatic(uint256 _tokenId) external payable nonReentrant whenNotPaused {
        require(isUsingMatic, Errors.NOT_USING_MATIC_NOW);
        require(blastEquipmentNFT.ownerOf(_tokenId) == msg.sender, Errors.NOT_OWNER);

        uint256 durabilityRestored;
        uint256 durabilityPoints;
        uint256 repairCount;
        (, durabilityRestored, durabilityPoints, , repairCount, ) = blastEquipmentNFT.getAttributes(_tokenId);
        if ((durabilityRestored + durabilityPoints) > 6) {
            uint256 maticPrice = getRepairPriceBLST(_tokenId);
            require(maticPrice > 0, Errors.INVALID_AMOUNT);
            require(msg.value == maticPrice, Errors.INVALID_AMOUNT);

            // Safe TransferFrom from msgSender to treasury
            (bool sent1, ) = payable(treasuryAddress).call{value: maticPrice / 4}("");
            require(sent1, Errors.FAILED_TO_SEND_ETHER_TREASURY);
            (bool sent2, ) = payable(companyAddress).call{value: (maticPrice - maticPrice / 4)}("");
            require(sent2, Errors.FAILED_TO_SEND_ETHER_COMPANY);
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, Errors.INVALID_AMOUNT);

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price);
        }

        blastEquipmentNFT.setRepairCount(_tokenId, repairCount + 1);

        emit Repaired(_tokenId, block.timestamp);
    }
}
