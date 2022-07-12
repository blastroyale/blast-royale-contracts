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
error NotReadyMorph();
error NoZeroAddress();
error NotReadyReplicate();
error InvalidParams();

contract Replicator is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct Parent {
        uint256 parent0;
        uint256 parent1;
    }

    uint8 public constant INIT_REPLICATION_COUNT = 7;
    uint256 public constant REPLICATION_TIMER = 5 days;
    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Token related Addresses
    IBlastEquipmentNFT public immutable blastEquipmentNFT;
    IERC20 public immutable blastToken;
    ERC20Burnable public immutable csToken;

    event Replicated(uint256 parent0, uint256 parent1, uint256 childId, address owner, uint256 timestamp);
    event Morphed(uint256 parent0, uint256 parent1, uint256 childId, address owner, uint256 timestamp);

    address private treasuryAddress;
    address private companyAddress;
    // Child Token ID : Parent Struct
    mapping (uint256 => Parent) public parents;
    // Child Token ID : morphTime
    mapping (uint256 => uint256) public morphTimestamp;
    // Parent Token ID : isReplicating
    mapping (uint256 => bool) public isReplicating;

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
        7e18,
        9e18,
        12e18,
        15e18,
        20e18,
        25e18,
        30e18
    ];

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param _blastEquipmentNFT : address of EquipmentNFT contract
    /// @param _blastToken : address of Primary Token
    /// @param _csToken : address of Secondary Token
    constructor (IBlastEquipmentNFT _blastEquipmentNFT, IERC20 _blastToken, ERC20Burnable _csToken, address _treasuryAddress, address _companyAddress) {
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
    }

    function setTreasuryAddress (address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) revert NoZeroAddress();
        treasuryAddress = _treasury;
    }

    function setCompanyAddress (address _company) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_company == address(0)) revert NoZeroAddress();
        companyAddress = _company;
    }

    function setCSPrices(uint[] calldata _csPrices) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_csPrices.length != 7) revert InvalidParams();
        for (uint8 i = 0; i < 7; i ++) {
            csPrices[i] = _csPrices[i];
        }
    }

    function setBLTPrices(uint[] calldata _bltPrices) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_bltPrices.length != 7) revert InvalidParams();
        for (uint8 i = 0; i < 7; i ++) {
            bltPrices[i] = _bltPrices[i];
        }
    }

    function replicate(string calldata _uri, bytes32 _hash, string calldata _realUri, uint256 _p1, uint256 _p2) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant whenNotPaused {
        if (_p1 == _p2) revert InvalidParams();
        if (
            blastEquipmentNFT.ownerOf(_p1) != msg.sender &&
            blastEquipmentNFT.getApproved(_p1) != address(this) &&
            !blastEquipmentNFT.isApprovedForAll(blastEquipmentNFT.ownerOf(_p1), address(this))
        ) revert NotOwner();
        if (
            blastEquipmentNFT.ownerOf(_p2) != msg.sender &&
            blastEquipmentNFT.getApproved(_p2) != address(this) &&
            !blastEquipmentNFT.isApprovedForAll(blastEquipmentNFT.ownerOf(_p2), address(this))
        ) revert NotOwner();

        if (isReplicating[_p1] || isReplicating[_p2]) revert NotReadyReplicate();

        uint256 currentReplicationCountP1;
        uint256 currentReplicationCountP2;
        (, , , currentReplicationCountP1) = blastEquipmentNFT.getAttributes(_p1);
        (, , , currentReplicationCountP2) = blastEquipmentNFT.getAttributes(_p2);
        uint256 totalCSAmount = csPrices[currentReplicationCountP1] + csPrices[currentReplicationCountP2];
        csToken.burnFrom(msg.sender, totalCSAmount);
        uint256 totalBltAmount = bltPrices[currentReplicationCountP1] + bltPrices[currentReplicationCountP2];
        if (totalBltAmount > 0) {
            blastToken.safeTransferFrom(msg.sender, treasuryAddress, totalBltAmount / 4);
            blastToken.safeTransferFrom(msg.sender, companyAddress, totalBltAmount * 3 / 4);
        }

        // TODO: Add a check to make sure the child token is not already replicated
        blastEquipmentNFT.setReplicationCount(_p1, currentReplicationCountP1 + 1);
        blastEquipmentNFT.setReplicationCount(_p2, currentReplicationCountP2 + 1);

        //MINT
        isReplicating[_p1] = true;
        isReplicating[_p2] = true;

        uint256 childTokenId = blastEquipmentNFT.safeMintReplicator(msg.sender, _uri, _hash, _realUri);
        parents[childTokenId] = Parent({
            parent0: _p1,
            parent1: _p2
        });
        morphTimestamp[childTokenId] = block.timestamp + REPLICATION_TIMER;

        emit Replicated(_p1, _p2, childTokenId, msg.sender, block.timestamp);
    }

    function isReplicatingStatus(uint256 _tokenId) internal view returns (bool) {
        return isReplicating[_tokenId];
    }

    function isReadyToMorph(uint256 _childId) public view returns (bool) {
        return morphTimestamp[_childId] <= block.timestamp;
    }

    function morph(uint256 _childId) external nonReentrant whenNotPaused {
        if (blastEquipmentNFT.ownerOf(_childId) != msg.sender) revert NotOwner();
        if (morphTimestamp[_childId] > block.timestamp) revert NotReadyMorph();

        Parent memory _parent = parents[_childId];
        isReplicating[_parent.parent0] = false;
        isReplicating[_parent.parent1] = false;

        blastEquipmentNFT.revealRealTokenURI(_childId);

        emit Morphed(_parent.parent0, _parent.parent1, _childId, msg.sender, block.timestamp);
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