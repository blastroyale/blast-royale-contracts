// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev required interface of an Equipment NFT.
 */
interface IEquipmentNFT is IERC721 {
  function attributes(uint256 tokenId, uint256 index) external returns(uint256 value);
  function safeMint(uint256 number, address to, string memory defaultURI) external;
  function setTokenURI(uint256[] memory tokenIds, string[] memory newURIs) external;
  function repair(uint256 tokenId) external;
  function setAttribute(uint256 tokenId, uint index, uint value) external;
  function incAttribute(uint256 tokenId, uint index) external;
  function tsAttribute(uint256 tokenId, uint index) external;
  function pause() external;
  function unpause() external;
}
