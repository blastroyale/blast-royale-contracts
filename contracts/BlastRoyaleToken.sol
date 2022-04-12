// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/// @title Blast Royale Token - $BLT
/// @dev Based on OpenZeppelin Contracts.
contract BlastRoyaleToken is ERC20, ERC20Pausable, Ownable {

  /// @notice Token constructor
  /// @dev Creates the token and setup the initial supply and the Admin Role.
  /// @param name Name of the Token
  /// @param symbol Symbol of the token
  /// @param admin The Admin (owner) of the contract
  /// @param _supply Initial Supply
  constructor(string memory name, string memory symbol, address admin, uint256 _supply)
    ERC20(name, symbol) {
    transferOwnership(admin);
    _mint(admin, _supply);
  }

  /// @notice Pauses the contract 
  /// @dev It stops transfer from happening. Only Owner can call it.
  function pause() public onlyOwner virtual {
    _pause();
  }

  /// @notice Unpauses the contract 
  /// @dev Transfers are possible again. Only Owner can call it.
  function unpause() public onlyOwner virtual {
    _unpause();
  }

  /// @notice Mint new tokens
  /// @param account new tokens owner
  /// @param amount Supply of tokens to be minted
  function mint(address account, uint256 amount) external onlyOwner {
    _mint(account, amount);
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
