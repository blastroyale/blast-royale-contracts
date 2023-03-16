// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract PrimaryToken is ERC20, ERC20Pausable, Ownable {
    /// @notice Token constructor
    /// @dev Creates the token and setup the initial supply and the Admin Role.
    /// @param name Name of the Token
    /// @param symbol Symbol of the token
    /// @param _treasury Treasury address
    /// @param _supply Initial Supply
    constructor(
        string memory name,
        string memory symbol,
        address _owner,
        address _treasury,
        uint256 _supply
    ) ERC20(name, symbol) {
        require(_treasury != address(0), "Treasury can't be zero address");
        require(_owner != address(0), "Owner can't be zero address");
        _mint(_treasury, _supply);
        _transferOwnership(_owner);
    }

    function pause(bool stop) public onlyOwner {
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
