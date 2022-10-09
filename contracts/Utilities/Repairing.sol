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
        uint256 durabilityRestored;
        uint256 durabilityPoint;
        (, durabilityRestored, durabilityPoint, , , ) = blastEquipmentNFT.getAttributes(_tokenId);
        uint256 temp = ((durabilityRestored * 2 + 10) * durabilityPoint) * 10 ** 17;
        if (temp == 0) {
            return 0;
        }
        return PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp), basePowerForCS), DECIMAL_FACTOR)) * basePriceForCS / DECIMAL_FACTOR;
    }

    function getRepairPriceBLST(uint256 _tokenId) public view returns (uint256) {
        uint256 durabilityRestored;
        uint256 durabilityPoint;
        int maticPrice = getLatestPrice();
        (, durabilityRestored, durabilityPoint, , , ) = blastEquipmentNFT.getAttributes(_tokenId);
        uint256 temp = ((durabilityRestored + 1) * durabilityPoint);
        if (temp == 0) {
            return 0;
        }
        uint256 priceInBLST = PRBMathUD60x18.exp2(PRBMathUD60x18.div(PRBMathUD60x18.mul(PRBMathUD60x18.log2(temp * 10 ** 18), basePowerForBLST), DECIMAL_FACTOR)) * basePriceForBLST / DECIMAL_FACTOR;
        if (isUsingMatic && maticPrice > 0) {
            return priceInBLST * uint256(maticPrice) / 10 ** 8;
        }
        return priceInBLST;
    }

    /// @notice Set Base Power for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePower(uint256 _basePowerForCS, uint256 _basePowerForBLST) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePowerForCS > 0, "Can't be zero");
        require(_basePowerForBLST > 0, "Can't be zero");

        basePowerForCS = _basePowerForCS;
        basePowerForBLST = _basePowerForBLST;

        emit BasePowerUpdated(_basePowerForCS, _basePowerForBLST);
    }

    /// @notice Set Base Price for CS and BLST. It will affect to calculate repair price for CS & BLST
    /// @dev The caller must have the `DEFAULT_ADMIN_ROLE`.
    function setBasePrice(uint256 _basePriceForCS, uint256 _basePriceForBLST) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_basePriceForCS > 0, "Can't be zero");
        require(_basePriceForBLST > 0, "Can't be zero");

        basePriceForCS = _basePriceForCS;
        basePriceForBLST = _basePriceForBLST;

        emit BasePriceUpdated(_basePriceForCS, _basePriceForBLST);
    }

    function repair(
        uint256 _tokenId
    ) external nonReentrant whenNotPaused {
        require(!isUsingMatic, "Using Matic");
        require(blastEquipmentNFT.ownerOf(_tokenId) == msg.sender, "Caller is not owner");
        uint256 durabilityRestored;
        uint256 durabilityPoints;
        uint256 repairCount;
        (, durabilityRestored, durabilityPoints, , repairCount, ) = blastEquipmentNFT.getAttributes(_tokenId);
        if ((durabilityRestored + durabilityPoints) > 6) {
            uint256 blstPrice = getRepairPriceBLST(_tokenId);
            require(blstPrice > 0, "Price can't be zero");

            // Safe TransferFrom from msgSender to treasury
            blastToken.safeTransferFrom(_msgSender(), treasuryAddress, blstPrice / 4);
            blastToken.safeTransferFrom(_msgSender(), companyAddress, (blstPrice - blstPrice / 4));
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, "Price can't be zero");

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price);
        }

        blastEquipmentNFT.setRepairCount(_tokenId, repairCount + 1);

        emit Repaired(_tokenId, block.timestamp);
    }

    function repairUsingMatic(uint256 _tokenId) external payable nonReentrant whenNotPaused {
        require(isUsingMatic, "Not using Matic");
        require(blastEquipmentNFT.ownerOf(_tokenId) == msg.sender, "Caller is not owner");

        uint256 durabilityRestored;
        uint256 durabilityPoints;
        uint256 repairCount;
        (, durabilityRestored, durabilityPoints, , repairCount, ) = blastEquipmentNFT.getAttributes(_tokenId);
        if ((durabilityRestored + durabilityPoints) > 6) {
            uint256 blstPrice = getRepairPriceBLST(_tokenId);
            require(blstPrice > 0, "Price can't be zero");
            require(msg.value == blstPrice, "Repair:Invalid Matic Amount");

            // Safe TransferFrom from msgSender to treasury
            (bool sent1, ) = payable(treasuryAddress).call{value: blstPrice / 4}("");
            require(sent1, "Failed to send treasuryAddress");
            (bool sent2, ) = payable(companyAddress).call{value: (blstPrice - blstPrice / 4)}("");
            require(sent2, "Failed to send companyAddress");
        } else {
            uint256 price = getRepairPrice(_tokenId);
            require(price > 0, "Price can't be zero");

            // Burning CS token from msgSender
            csToken.burnFrom(_msgSender(), price);
        }

        blastEquipmentNFT.setRepairCount(_tokenId, repairCount + 1);

        emit Repaired(_tokenId, block.timestamp);
    }
}
