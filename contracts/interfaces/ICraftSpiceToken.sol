// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev interface of secondary token
 */
interface ICraftSpiceToken is IERC20 {
    function claim(address _to, uint256 _amount) external;
}
