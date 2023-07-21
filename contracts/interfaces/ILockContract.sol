// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ILockContract {
    function withdrawERC1155(
        address tokenContract,
        address withdrawer,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external;
}
