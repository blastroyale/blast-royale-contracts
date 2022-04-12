// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev required interface of a Craftship Token .
 */
interface ICraftshipToken is IERC20 {
  function mint(uint256 number, bytes calldata signature) external;
  function nonce(address to) external returns(uint256);
  function burnFrom(address account, uint256 amount) external;
  function pause() external;
  function unpause() external;
}
