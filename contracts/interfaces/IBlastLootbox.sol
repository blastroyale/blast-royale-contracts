// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev required interface of an Lootbox NFT.
 */
interface IBlastLootbox is IERC721 {
    event Open(uint lootboxId, uint token0, uint token1, uint token2);

    function getTokenType(uint _tokenId) external view returns (uint8);
}
