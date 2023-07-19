// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ContractTypeChecker {
    function isERC721OrERC1155(
        address contractAddress
    ) internal view returns (uint256) {
        if (isERC721(contractAddress)) {
            return 721;
        } else if (isERC1155(contractAddress)) {
            return 1155;
        } else {
            return 999;
        }
    }

    function isERC721(address contractAddress) internal view returns (bool) {
        try IERC721(contractAddress).supportsInterface(0x80ac58cd) returns (
            bool supported
        ) {
            return supported;
        } catch {
            return false;
        }
    }

    function isERC1155(address contractAddress) internal view returns (bool) {
        try IERC1155(contractAddress).supportsInterface(0xd9b67a26) returns (
            bool supported
        ) {
            return supported;
        } catch {
            return false;
        }
    }
}
