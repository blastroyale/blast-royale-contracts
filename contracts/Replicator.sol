// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBlastEquipmentNFT.sol";
import "hardhat/console.sol";

error NotOwner();

contract Replicator is AccessControl {
    uint8 public constant INIT_REPLICATION_COUNT = 7;
    uint public constant REPLICATION_TIMER = 5 days;

    event Replicated(uint indexed f1, uint indexed f2, address owner);

    IBlastEquipmentNFT public blastEquipmentNFT;
    IERC20 public blastToken;
    IERC20 public csToken;

    uint256[7] internal csPrices = [
        22500e18,
        14000e18,
        9000e18,
        5000e18,
        3200e18,
        1800e18,
        1250e18
    ];
    uint256[7] internal bltPrices = [
        100e18,
        80e18,
        65e18,
        50e18,
        40e18,
        30e18,
        25e18
    ];

    constructor (IBlastEquipmentNFT _blastEquipmentNFT, IERC20 _blastToken, IERC20 _csToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
    }

    function setBlastEquipmentNFT(IBlastEquipmentNFT _blastEquipmentNFT) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    function replicate(uint _f1, uint _f2) external {
        if(blastEquipmentNFT.ownerOf(_f1) != msg.sender) revert NotOwner();
        if(blastEquipmentNFT.ownerOf(_f2) != msg.sender) revert NotOwner();

        uint currentReplicationCountF1;
        uint currentReplicationCountF2;
        (, , , currentReplicationCountF1) = blastEquipmentNFT.getAttributes(_f1);
        (, , , currentReplicationCountF2) = blastEquipmentNFT.getAttributes(_f2);
        uint totalCSAmount = csPrices[currentReplicationCountF1] + csPrices[currentReplicationCountF2];
        csToken.transferFrom(msg.sender, address(this), totalCSAmount);
        uint totalBltAmount = bltPrices[currentReplicationCountF1] + bltPrices[currentReplicationCountF2];
        blastToken.transferFrom(msg.sender, address(this), totalBltAmount);

        emit Replicated(_f1, _f2, msg.sender);
    }
}