// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./interfaces/IBlastEquipmentNFT.sol";

error NotOwner();
error NotReadyMorph();
error NoZeroAddress();
error NotReadyReplicate();
error InvalidParams();
error InvalidSignature();

contract Replicator is AccessControl, EIP712, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    struct Parent {
        uint256 parent0;
        uint256 parent1;
    }

    bytes32 public constant REPLICATOR_TYPEHASH = keccak256("REPLICATOR(address sender,string uri,bytes32 hash,string realUri,uint256 p1,uint256 p2,uint256 nonce,uint256 deadline)");
    // Token related Addresses
    IBlastEquipmentNFT public immutable blastEquipmentNFT;
    IERC20 public immutable blastToken;
    ERC20Burnable public immutable csToken;

    address private signer;
    mapping(address => uint256) public nonces;
    uint8 public constant INIT_REPLICATION_COUNT = 7;
    // TODO: It would be 5 days in public release. (5 days)
    uint256 public constant REPLICATION_TIMER = 5 minutes;

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

    address private treasuryAddress;
    address private companyAddress;
    // Child Token ID : Parent Struct
    mapping(uint256 => Parent) public parents;
    // Child Token ID : morphTime
    mapping(uint256 => uint256) public morphTimestamp;
    // Parent Token ID : isReplicating
    mapping(uint256 => bool) public isReplicating;

    uint256[7] public csPrices = [
        1250e18,
        1800e18,
        3200e18,
        5000e18,
        9000e18,
        14000e18,
        22500e18
    ];
    uint256[7] public bltPrices = [
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
    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress,
        address _signer
    ) EIP712("REPLICATOR", "1.0.0") {
        if (
            address(_blastEquipmentNFT) == address(0) ||
            address(_blastToken) == address(0) ||
            address(_csToken) == address(0) ||
            _treasuryAddress == address(0) ||
            _companyAddress == address(0) ||
            _signer == address(0)
        ) revert NoZeroAddress();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
        treasuryAddress = _treasuryAddress;
        companyAddress = _companyAddress;
        signer = _signer;
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

    function setCSPrices(uint256[] calldata _csPrices)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_csPrices.length != 7) revert InvalidParams();
        for (uint8 i = 0; i < 7; i++) {
            csPrices[i] = _csPrices[i];
        }
    }

    function setBLTPrices(uint256[] calldata _bltPrices)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_bltPrices.length != 7) revert InvalidParams();
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
        uint256 _deadline, 
        bytes calldata _signature
    ) external nonReentrant whenNotPaused {
        if (_p1 == _p2) revert InvalidParams();
        address tokenOwner = blastEquipmentNFT.ownerOf(_p1);
        if (tokenOwner != blastEquipmentNFT.ownerOf(_p2)) revert InvalidParams();
        if (tokenOwner != msg.sender) revert InvalidParams();

        if (isReplicating[_p1] || isReplicating[_p2])
            revert NotReadyReplicate();

        bytes32 _hash = keccak256(abi.encodePacked(_hashString));

        if (block.timestamp >= _deadline) revert InvalidParams();
        require(_verify(_hashFunc(_msgSender(), _uri, _hash, _realUri, _p1, _p2, nonces[_msgSender()], _deadline), _signature), "Replicator:Invalid Signature");
        nonces[_msgSender()] ++;

        setReplicatorCount(_p1, _p2, tokenOwner);

        //MINT
        isReplicating[_p1] = true;
        isReplicating[_p2] = true;

        uint256 childTokenId = blastEquipmentNFT.safeMintReplicator(
            tokenOwner,
            _uri,
            _hash,
            _realUri
        );
        parents[childTokenId] = Parent({parent0: _p1, parent1: _p2});
        morphTimestamp[childTokenId] = block.timestamp + REPLICATION_TIMER;

        emit Replicated(_p1, _p2, childTokenId, tokenOwner, block.timestamp);
    }

    function setReplicatorCount(uint256 _p1, uint256 _p2, address tokenOwner) internal {
        uint256 currentReplicationCountP1;
        uint256 currentReplicationCountP2;
        (, , , currentReplicationCountP1) = blastEquipmentNFT.getAttributes(_p1);
        (, , , currentReplicationCountP2) = blastEquipmentNFT.getAttributes(_p2);
        csToken.burnFrom(
            tokenOwner,
            csPrices[currentReplicationCountP1] +
                csPrices[currentReplicationCountP2]
        );
        uint256 totalBltAmount = bltPrices[currentReplicationCountP1] +
            bltPrices[currentReplicationCountP2];
        if (totalBltAmount > 0) {
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

    function _verify(bytes32 digest, bytes memory signature) internal view returns (bool)
    {
        return ECDSA.recover(digest, signature) == signer;
    }

    function _hashFunc(
        address _sender,
        string calldata _uri,
        bytes32 _hash,
        string calldata _realUri,
        uint256 _p1,
        uint256 _p2,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(
            REPLICATOR_TYPEHASH,
            _sender,
            keccak256(abi.encodePacked(_uri)),
            _hash,
            keccak256(abi.encodePacked(_realUri)),
            _p1,
            _p2,
            nonce,
            deadline
        )));
    }

    function isReplicatingStatus(uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return isReplicating[_tokenId];
    }

    function isReadyToMorph(uint256 _childId) public view returns (bool) {
        return morphTimestamp[_childId] <= block.timestamp;
    }

    function morph(uint256 _childId) external nonReentrant whenNotPaused {
        if (blastEquipmentNFT.ownerOf(_childId) != msg.sender)
            revert NotOwner();
        if (morphTimestamp[_childId] > block.timestamp) revert NotReadyMorph();

        Parent memory _parent = parents[_childId];
        isReplicating[_parent.parent0] = false;
        isReplicating[_parent.parent1] = false;

        blastEquipmentNFT.revealRealTokenURI(_childId);

        emit Morphed(
            _parent.parent0,
            _parent.parent1,
            _childId,
            msg.sender,
            block.timestamp
        );
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
