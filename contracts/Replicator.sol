// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

error NotOwner();
error NotReadyMorph();
error NoZeroAddress();
error InvalidParams();

contract Replicator is AccessControl {
    using SafeERC20 for IERC20;

    struct Parent {
        uint parent0;
        uint parent1;
    }

    uint8 public constant INIT_REPLICATION_COUNT = 7;
    uint public constant REPLICATION_TIMER = 5 days;

    // Token related Addresses
    IBlastEquipmentNFT public immutable blastEquipmentNFT;
    IERC20 public immutable blastToken;
    IERC20 public immutable csToken;

    event Replicated(uint indexed parent0, uint indexed parent1, uint childId, address owner, uint timestamp);

    // Child Token ID : Parent Struct
    mapping (uint => Parent) public parents;
    // Child Token ID : morphTime
    mapping (uint => uint) public morphTimestamp;
    // Parent Token ID : isReplicating
    mapping (uint => bool) public isReplicating;

    uint256[7] private csPrices = [
        1250e18,
        1800e18,
        3200e18,
        5000e18,
        9000e18,
        14000e18,
        22500e18
    ];
    uint256[7] private bltPrices = [
        25e18,
        30e18,
        40e18,
        50e18,
        65e18,
        80e18,
        100e18
    ];

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param _blastEquipmentNFT : address of EquipmentNFT contract
    /// @param _blastToken : address of Primary Token
    /// @param _csToken : address of Secondary Token
    constructor (IBlastEquipmentNFT _blastEquipmentNFT, IERC20 _blastToken, IERC20 _csToken) {
        if (address(_blastEquipmentNFT) == address(0) || address(_blastToken) == address(0) || address(_csToken) == address(0)) revert NoZeroAddress();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
    }

    function setCSPrices(uint[] memory _csPrices) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_csPrices.length != 7) revert InvalidParams();
        for (uint i = 0; i < 7; i ++) {
            csPrices[i] = _csPrices[i];
        }
    }

    function setBLTPrices(uint[] memory _bltPrices) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_bltPrices.length != 7) revert InvalidParams();
        for (uint i = 0; i < 7; i ++) {
            bltPrices[i] = _bltPrices[i];
        }
    }

    function replicate(string memory _uri, bytes32 _hash, string memory _realUri, uint _p1, uint _p2) external {
        if (_p1 == _p2) revert InvalidParams();
        if (blastEquipmentNFT.ownerOf(_p1) != msg.sender) revert NotOwner();
        if (blastEquipmentNFT.ownerOf(_p2) != msg.sender) revert NotOwner();

        uint currentReplicationCountP1;
        uint currentReplicationCountP2;
        (, , , currentReplicationCountP1) = blastEquipmentNFT.getAttributes(_p1);
        (, , , currentReplicationCountP2) = blastEquipmentNFT.getAttributes(_p2);
        uint totalCSAmount = csPrices[currentReplicationCountP1] + csPrices[currentReplicationCountP2];
        csToken.safeTransferFrom(msg.sender, address(this), totalCSAmount);
        uint totalBltAmount = bltPrices[currentReplicationCountP1] + bltPrices[currentReplicationCountP2];
        blastToken.safeTransferFrom(msg.sender, address(this), totalBltAmount);
        //MINT
        isReplicating[_p1] = true;
        isReplicating[_p2] = true;

        uint childTokenId = blastEquipmentNFT.safeMintReplicator(msg.sender, _uri, _hash, _realUri);
        parents[childTokenId] = Parent({
            parent0: _p1,
            parent1: _p2
        });
        morphTimestamp[childTokenId] = block.timestamp + REPLICATION_TIMER;

        emit Replicated(_p1, _p2, childTokenId, msg.sender, block.timestamp);
    }

    function isReplicatingStatus(uint _tokenId) internal view returns (bool) {
        return isReplicating[_tokenId];
    }

    function isReadyToMorph(uint _childId) public view returns (bool) {
        return morphTimestamp[_childId] <= block.timestamp;
    }

    function morph(uint _childId) external {
        if (blastEquipmentNFT.ownerOf(_childId) != msg.sender) revert NotOwner();
        if (morphTimestamp[_childId] > block.timestamp) revert NotReadyMorph();

        Parent memory _parent = parents[_childId];
        isReplicating[_parent.parent0] = false;
        isReplicating[_parent.parent1] = false;

        blastEquipmentNFT.revealRealTokenURI(_childId);
    }
}