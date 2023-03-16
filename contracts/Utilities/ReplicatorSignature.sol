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
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./../interfaces/IBlastEquipmentNFT.sol";

error NotOwner();
error NotReadyMorph();
error NoZeroAddress();
error NotReadyReplicate();
error InvalidParams();
error InvalidSignature();

contract ReplicatorSignature is AccessControl, EIP712, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    struct Parent {
        uint256 parent0;
        uint256 parent1;
    }

    AggregatorV3Interface internal priceFeed;

    bytes32 public constant REPLICATOR_TYPEHASH = keccak256("REPLICATOR(address sender,string uri,string hash,string realUri,uint256 p1,uint256 p2,uint256 nonce,uint256 deadline)");
    // Token related Addresses
    IBlastEquipmentNFT public blastEquipmentNFT;
    IERC20 public blastToken;
    ERC20Burnable public csToken;

    address private signer;
    mapping(address => uint256) public nonces;
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
    bool public isUsingMatic;
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

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
        treasuryAddress = _treasuryAddress;
        companyAddress = _companyAddress;
        signer = _signer;

        priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
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

    function setBlastEquipmentAddress(IBlastEquipmentNFT _blastEquipmentNFT)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastEquipmentNFT) != address(0), "NoZeroAddress");
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    function setBlastTokenAddress(IERC20 _blastToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastToken) != address(0), "NoZeroAddress");
        blastToken = _blastToken;
    }

    function setCSTokenAddress(ERC20Burnable _csToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_csToken) != address(0), "NoZeroAddress");
        csToken = _csToken;
    }

    function toggleIsUsingMatic() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isUsingMatic = !isUsingMatic;
    }

    function replicate(
        string calldata _uri,
        string calldata _hashString,
        string calldata _realUri,
        uint256 _p1,
        uint256 _p2,
        uint256 _deadline,
        bytes calldata _signature,
        StaticAttributes calldata _staticAttribute
    ) external payable nonReentrant whenNotPaused {
        if (_p1 == _p2) revert InvalidParams();
        if (blastEquipmentNFT.ownerOf(_p1) != blastEquipmentNFT.ownerOf(_p2)) revert InvalidParams();
        if (blastEquipmentNFT.ownerOf(_p1) != _msgSender()) revert InvalidParams();

        if (isReplicating[_p1] || isReplicating[_p2])
            revert NotReadyReplicate();

        if (block.timestamp >= _deadline) revert InvalidParams();

        require(_verify(_hashFunc(_msgSender(), _uri, _hashString, _realUri, _p1, _p2, nonces[_msgSender()], _deadline), _signature), "Replicator:Invalid Signature");
        nonces[_msgSender()] ++;

        setReplicatorCount(_p1, _p2, blastEquipmentNFT.ownerOf(_p1));

        uint childTokenId = mintChild(blastEquipmentNFT.ownerOf(_p1), _hashString, _realUri, _p1, _p2, _staticAttribute);

        emit Replicated(_p1, _p2, childTokenId, blastEquipmentNFT.ownerOf(_p1), block.timestamp);
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
        revert("fail");
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
        uint256 currentReplicationCountP1;
        uint256 currentReplicationCountP2;
        (, , , , , currentReplicationCountP1) = blastEquipmentNFT.getAttributes(_p1);
        (, , , , , currentReplicationCountP2) = blastEquipmentNFT.getAttributes(_p2);
        csToken.burnFrom(
            tokenOwner,
            csPrices[currentReplicationCountP1] +
                csPrices[currentReplicationCountP2]
        );
        uint256 totalBltAmount = bltPrices[currentReplicationCountP1] +
            bltPrices[currentReplicationCountP2];
        if (isUsingMatic) {
            require(msg.value == totalBltAmount, "Replicator:Invalid Matic Amount");
            (bool sent1, ) = payable(treasuryAddress).call{value: totalBltAmount / 4}("");
            require(sent1, "Failed to send treasuryAddress");
            (bool sent2, ) = payable(companyAddress).call{value: (totalBltAmount * 3) / 4}("");
            require(sent2, "Failed to send companyAddress");
        } else {
            require(msg.value == 0, "Replicator:Invalid Value");
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

    function mintChild(address tokenOwner, string calldata _hashString, string calldata _realUri, uint256 _p1, uint256 _p2, StaticAttributes calldata _staticAttribute) internal returns (uint256) {
        uint256 childTokenId = blastEquipmentNFT.safeMintReplicator(
            tokenOwner,
            bytes32(fromHex(_hashString)),
            _realUri,
            _staticAttribute
        );
        isReplicating[childTokenId] = true;
        parents[childTokenId] = Parent({parent0: _p1, parent1: _p2});
        morphTimestamp[childTokenId] = block.timestamp + REPLICATION_TIMER;

        return childTokenId;
    }

    function _verify(bytes32 digest, bytes memory signature) internal view returns (bool)
    {
        return ECDSA.recover(digest, signature) == signer;
    }

    function _hashFunc(
        address _sender,
        string calldata _uri,
        string calldata _hash,
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
            keccak256(abi.encodePacked(_hash)),
            keccak256(abi.encodePacked(_realUri)),
            _p1,
            _p2,
            nonce,
            deadline
        )));
    }

    function morph(uint256 _childId) external nonReentrant whenNotPaused {
        if (blastEquipmentNFT.ownerOf(_childId) != _msgSender())
            revert NotOwner();
        if (morphTimestamp[_childId] > block.timestamp) revert NotReadyMorph();

        Parent memory _parent = parents[_childId];
        isReplicating[_childId] = false;

        blastEquipmentNFT.revealRealTokenURI(_childId);

        emit Morphed(
            _parent.parent0,
            _parent.parent1,
            _childId,
            _msgSender(),
            block.timestamp
        );
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
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
