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

contract Replicator is Utility {
    using SafeERC20 for IERC20;

    struct Parent {
        uint256 parent0;
        uint256 parent1;
    }

    mapping(address => uint256) public nonces;
    uint256 public replicationTimer = 5 minutes;

    event Replicated(
        uint256 parent0,
        uint256 parent1,
        uint256 childId,
        address owner,
        uint256 timestamp
    );
    event Morphed(
        uint256 parent0,
        uint256 parent1,
        uint256 childId,
        address owner,
        uint256 timestamp
    );

    // Child Token ID : Parent Struct
    mapping(uint256 => Parent) public parents;
    // Child Token ID : morphTime
    mapping(uint256 => uint256) public morphTimestamp;
    // Parent Token ID : isReplicating
    mapping(uint256 => bool) public isReplicating;

    uint256[7] public csPrices = [
        1250e18, 1800e18, 3200e18, 5000e18,
        9000e18, 14000e18, 22500e18
    ];
    uint256[7] public maticCsPrices = [
        4050e18, 5400e18, 8000e18, 11000e18,
        17000e18, 24000e18, 34500e18
    ];
    uint256[7] public bltPrices = [
        7e18, 9e18, 12e18, 15e18,
        20e18, 25e18, 30e18
    ];

    /// @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
    /// @param _blastEquipmentNFT : address of EquipmentNFT contract
    /// @param _blastToken : address of Primary Token
    /// @param _csToken : address of Secondary Token
    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress
    ) Utility(_blastEquipmentNFT, _blastToken, _csToken, _treasuryAddress, _companyAddress) {
    }

    function setCSPrices(uint256[] calldata _csPrices)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_csPrices.length == 7, Errors.INVALID_PARAM);
        for (uint8 i = 0; i < 7; i++) {
            csPrices[i] = _csPrices[i];
        }
    }

    function setBLTPrices(uint256[] calldata _bltPrices)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_bltPrices.length == 7, Errors.INVALID_PARAM);
        for (uint8 i = 0; i < 7; i++) {
            bltPrices[i] = _bltPrices[i];
        }
    }

    function replicate(
        string calldata _uri,
        string calldata _hashString,
        string calldata _realUri,
        uint256 _p1,
        uint256 _p2,
        StaticAttributes calldata _staticAttribute
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant whenNotPaused {
        require(_p1 != _p2, Errors.INVALID_PARAM);
        address tokenOwner = blastEquipmentNFT.ownerOf(_p1);
        require(tokenOwner == blastEquipmentNFT.ownerOf(_p2), Errors.INVALID_PARAM);
        require(!isReplicating[_p1] && !isReplicating[_p2], Errors.NOT_READY_REPLICATE);

        setReplicatorCount(_p1, _p2, tokenOwner);

        uint childTokenId = mintChild(tokenOwner, _uri, _hashString, _realUri, _p1, _p2, _staticAttribute);

        emit Replicated(_p1, _p2, childTokenId, tokenOwner, block.timestamp);
    }

    // Convert an hexadecimal character to their value
    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert(Errors.INVALID_HEX_CHARACTER);
    }

    // Convert an hexadecimal string to raw bytes
    function fromHex(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length%2 == 0); // length must be even
        bytes memory r = new bytes(ss.length/2);
        for (uint i=0; i<ss.length/2; ++i) {
            r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 +
                        fromHexChar(uint8(ss[2*i+1])));
        }
        return r;
    }

    function setReplicatorCount(uint256 _p1, uint256 _p2, address tokenOwner) internal {
        (, , , , , uint256 currentReplicationCountP1) = blastEquipmentNFT.getAttributes(_p1);
        (, , , , , uint256 currentReplicationCountP2) = blastEquipmentNFT.getAttributes(_p2);
        uint256 totalCSAmount = getTotalCSAmount(currentReplicationCountP1, currentReplicationCountP2);
        csToken.burnFrom(tokenOwner, totalCSAmount);
        if (!isUsingMatic) {
            uint256 totalBltAmount = getTotalBLSTAmount(currentReplicationCountP1, currentReplicationCountP2);
            blastToken.safeTransferFrom(
                tokenOwner,
                treasuryAddress,
                totalBltAmount / 4
            );
            blastToken.safeTransferFrom(
                tokenOwner,
                companyAddress,
                (totalBltAmount * 3) / 4
            );
        }
        blastEquipmentNFT.setReplicationCount(
            _p1,
            currentReplicationCountP1 + 1
        );
        blastEquipmentNFT.setReplicationCount(
            _p2,
            currentReplicationCountP2 + 1
        );
    }

    function mintChild(address tokenOwner, string calldata _uri, string calldata _hashString, string calldata _realUri, uint256 _p1, uint256 _p2, StaticAttributes calldata _staticAttribute) internal returns (uint256) {
        uint256 childTokenId = blastEquipmentNFT.safeMintReplicator(
            tokenOwner,
            _uri,
            bytes32(fromHex(_hashString)),
            _realUri,
            _staticAttribute
        );
        isReplicating[childTokenId] = true;
        parents[childTokenId] = Parent({parent0: _p1, parent1: _p2});
        morphTimestamp[childTokenId] = block.timestamp + replicationTimer;

        return childTokenId;
    }

    function morph(uint256 _childId) external nonReentrant whenNotPaused {
        require(blastEquipmentNFT.ownerOf(_childId) == msg.sender, Errors.NOT_OWNER);
        require(morphTimestamp[_childId] != 0 && morphTimestamp[_childId] <= block.timestamp, Errors.NOT_READY_MORPH);

        Parent memory _parent = parents[_childId];
        isReplicating[_childId] = false;

        blastEquipmentNFT.revealRealTokenURI(_childId);

        emit Morphed(
            _parent.parent0,
            _parent.parent1,
            _childId,
            msg.sender,
            block.timestamp
        );
    }

    function setReplicationTimer(uint _newTimer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newTimer > 0, Errors.NO_ZERO_VALUE);
        replicationTimer = _newTimer;
    }

    function getTotalCSAmount(uint256 currentReplicationCountP1, uint256 currentReplicationCountP2) public view returns (uint256) {
        if (isUsingMatic) {
            return maticCsPrices[currentReplicationCountP1] + maticCsPrices[currentReplicationCountP2];
        }
        return csPrices[currentReplicationCountP1] + csPrices[currentReplicationCountP2];
    }

    function getTotalBLSTAmount(uint256 currentReplicationCountP1, uint256 currentReplicationCountP2) public view returns (uint256) {
        return bltPrices[currentReplicationCountP1] + bltPrices[currentReplicationCountP2];
    }
}
