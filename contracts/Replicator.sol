// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

error NotOwner();
error NotReadyMorph();

contract Replicator is AccessControl {

    struct Parent {
        uint parent0;
        uint parent1;
    }

    uint8 public constant INIT_REPLICATION_COUNT = 7;
    uint public constant REPLICATION_TIMER = 5 days;

    event Replicated(uint indexed f1, uint indexed f2, address owner, uint timestamp);

    mapping (uint => Parent) public parents;
    mapping (uint => uint) public morphTimestamp;
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

    function replicate(string memory _uri, bytes32 _hash, string memory _realUri, uint _f1, uint _f2) external {
        if (blastEquipmentNFT.ownerOf(_f1) != msg.sender) revert NotOwner();
        if (blastEquipmentNFT.ownerOf(_f2) != msg.sender) revert NotOwner();

        uint currentReplicationCountF1;
        uint currentReplicationCountF2;
        (, , , currentReplicationCountF1) = blastEquipmentNFT.getAttributes(_f1);
        (, , , currentReplicationCountF2) = blastEquipmentNFT.getAttributes(_f2);
        uint totalCSAmount = csPrices[currentReplicationCountF1] + csPrices[currentReplicationCountF2];
        csToken.transferFrom(msg.sender, address(this), totalCSAmount);
        uint totalBltAmount = bltPrices[currentReplicationCountF1] + bltPrices[currentReplicationCountF2];
        blastToken.transferFrom(msg.sender, address(this), totalBltAmount);
        //MINT
        uint childTokenId = blastEquipmentNFT.safeMintReplicator(msg.sender, _uri, _hash, _realUri);
        parents[childTokenId] = Parent({
            parent0: _f1,
            parent1: _f2
        });
        morphTimestamp[childTokenId] = block.timestamp + REPLICATION_TIMER;

        emit Replicated(_f1, _f2, msg.sender, block.timestamp);
    }

    function morph(uint _tokenId) external {
        if (blastEquipmentNFT.ownerOf(_tokenId) != msg.sender) revert NotOwner();
        if (morphTimestamp[_tokenId] > block.timestamp) revert NotReadyMorph();

        blastEquipmentNFT.revealRealTokenURI(_tokenId);
    }
}