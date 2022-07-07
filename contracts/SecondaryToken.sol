// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Blast Royale Token - Secondary Token
/// @dev Based on OpenZeppelin Contracts.
contract SecondaryToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Token constructor
    /// @dev Creates the token and setup the initial supply and the Admin Role.
    /// @param name Name of the Token
    /// @param symbol Symbol of the token
    /// @param _initialSupply Initial Supply
    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply
    ) ERC20(name, symbol) {
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
    }

    /// @notice Pauses the contract
    /// @dev It stops transfer from happening. Only Owner can call it.
    function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev Transfers are possible again. Only Owner can call it.
    function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
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
