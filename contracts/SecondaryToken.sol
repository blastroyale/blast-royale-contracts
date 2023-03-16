// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICraftSpiceToken.sol";
import { Errors } from "./libraries/Errors.sol";

/// @title Blast Royale Token - Secondary Token
/// @dev Based on OpenZeppelin Contracts.
contract SecondaryToken is ERC20, ERC20Burnable, ICraftSpiceToken, ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Claimed(address user, uint256 amount);
    event MintedFromScrap(address user, uint256 amount);

    /// @notice Token constructor
    /// @dev Creates the token and setup the initial supply and the Admin Role.
    /// @param name Name of the Token
    /// @param symbol Symbol of the token
    /// @param _initialSupply Initial Supply
    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply,
        address _signer
    ) ERC20(name, symbol) {
        require(_signer != address(0));
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _mint(_msgSender(), _initialSupply);
    }

    /// @notice Mint new tokens
    /// @param _to Target Address
    /// @param _amount Token Amount
    function claim(address _to, uint256 _amount)
        external
        onlyRole(MINTER_ROLE)
    {
        _mint(_to, _amount);

        emit Claimed(_to, _amount);
    }

    /// @notice Mint new tokens
    /// @param _to Target Address
    /// @param _amount Token Amount
    function mintFromScrap(address _to, uint256 _amount)
        external
        override
        onlyRole(MINTER_ROLE)
    {
        _mint(_to, _amount);

        emit MintedFromScrap(_to, _amount);
    }

    function pause(bool stop) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @notice Verifications before Token Transfer
    /// @param from Address from
    /// @param from to Address from
    /// @param amount tokens to be transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
