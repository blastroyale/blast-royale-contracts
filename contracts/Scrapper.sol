// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBlastEquipmentNFT.sol";
import "./interfaces/ICraftSpiceToken.sol";

error NoZeroAddress();

contract Scrapper is AccessControl, ReentrancyGuard, Pausable {
    IBlastEquipmentNFT public blastEquipmentNFT;
    ICraftSpiceToken public csToken;

    constructor (IBlastEquipmentNFT _blastEquipmentNFT, ICraftSpiceToken _csToken) {
        if (
            address(_blastEquipmentNFT) == address(0) ||
            address(_csToken) == address(0)
        ) revert NoZeroAddress();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        blastEquipmentNFT = _blastEquipmentNFT;
        csToken = _csToken;
    }

    function scrap(uint256 _tokenId) external {
        require(
            blastEquipmentNFT.ownerOf(_tokenId) == msg.sender,
            "Scrapper: Not owner of token"
        );
        csToken.claim(_msgSender(), 1);
        blastEquipmentNFT.scrap(_tokenId);
    }

    function setBlastEquipmentAddress(IBlastEquipmentNFT _blastEquipmentNFT)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_blastEquipmentNFT) != address(0), "NoZeroAddress");
        blastEquipmentNFT = _blastEquipmentNFT;
    }

    function setCSTokenAddress(ICraftSpiceToken _csToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_csToken) != address(0), "NoZeroAddress");
        csToken = _csToken;
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