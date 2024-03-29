// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./../interfaces/IBlastEquipmentNFT.sol";
import { Errors } from "./../libraries/Errors.sol";

abstract contract Utility is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_FACTOR = 1000;

    IBlastEquipmentNFT public blastEquipmentNFT;
    IERC20 public blastToken;
    ERC20Burnable public csToken;

    address internal treasuryAddress;
    address internal companyAddress;
    bool public isUsingMatic;

    constructor(
        IBlastEquipmentNFT _blastEquipmentNFT,
        IERC20 _blastToken,
        ERC20Burnable _csToken,
        address _treasuryAddress,
        address _companyAddress
    ) {
        require(
            address(_blastEquipmentNFT) != address(0) &&
            address(_blastToken) != address(0) &&
            address(_csToken) != address(0) &&
            _treasuryAddress != address(0) &&
            _companyAddress != address(0),
            Errors.NO_ZERO_ADDRESS
        );

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        blastEquipmentNFT = _blastEquipmentNFT;
        blastToken = _blastToken;
        csToken = _csToken;
        treasuryAddress = _treasuryAddress;
        companyAddress = _companyAddress;
    }

    function setTreasuryAddress(address _treasury)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_treasury != address(0), Errors.NO_ZERO_ADDRESS);
        treasuryAddress = _treasury;
    }

    function setCompanyAddress(address _company)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_company != address(0), Errors.NO_ZERO_ADDRESS);
        companyAddress = _company;
    }

    function setBlastEquipmentAddress(IBlastEquipmentNFT _blastEquipmentNFT)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastEquipmentNFT) != address(0), Errors.NO_ZERO_ADDRESS);
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    function setBlastTokenAddress(IERC20 _blastToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastToken) != address(0), Errors.NO_ZERO_ADDRESS);
        blastToken = _blastToken;
    }

    function setCSTokenAddress(ERC20Burnable _csToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_csToken) != address(0), Errors.NO_ZERO_ADDRESS);
        csToken = _csToken;
    }

    function flipIsUsingMatic() public onlyRole(DEFAULT_ADMIN_ROLE) {
        isUsingMatic = !isUsingMatic;
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