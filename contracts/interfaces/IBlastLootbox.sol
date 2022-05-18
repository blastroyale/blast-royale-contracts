// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev required interface of an Lootbox NFT.
 */
interface IBlastLootbox is IERC721 {
    function getTokenType(uint _tokenId) external view returns (uint8);
}
