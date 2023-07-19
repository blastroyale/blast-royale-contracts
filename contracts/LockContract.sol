// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LockContract is
    AccessControl,
    ERC1155Holder,
    ERC721Holder,
    Pausable,
    ReentrancyGuard
{
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    mapping(address => bool) public whitelistedContracts;
    mapping(address => bool) public whitelistedBurnableContracts;
    mapping(address => mapping(uint256 => uint256)) public lockedERC1155Tokens;
    mapping(address => mapping(uint256 => bool)) public lockedERC721Tokens;

    modifier onlyWhitelisted(address tokenContract) {
        require(
            whitelistedContracts[tokenContract],
            "Token contract is not whitelisted"
        );
        _;
    }

    modifier onlyBurnableWhitelisted(address tokenContract) {
        require(
            whitelistedBurnableContracts[tokenContract],
            "Token contract is not whitelisted"
        );
        _;
    }

    event WhitelistedBurnableContractAdded(address tokenContract);
    event WhitelistedBurnableContractRemoved(address tokenContract);

    event WhitelistedContractAdded(address tokenContract);

    event WhitelistedContractRemoved(address tokenContract);

    event ERC1155Locked(
        address locker,
        address tokenContract,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event ERC721Burnt(
        address burner,
        address tokenContract,
        uint256[] tokenIds
    );

    event NFTWithdraw(
        address withdrawer,
        address tokenContract,
        uint256[] tokenIds,
        uint256[] amounts
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WITHDRAW_ROLE, msg.sender);
    }

    function addWhitelistedBurnableContract(
        address tokenContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedBurnableContracts[tokenContract] = true;
        emit WhitelistedBurnableContractAdded(tokenContract);
    }

    function removeWhitelistedBurnableContract(
        address tokenContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete whitelistedBurnableContracts[tokenContract];
        emit WhitelistedBurnableContractRemoved(tokenContract);
    }

    function addWhitelistedContract(
        address tokenContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedContracts[tokenContract] = true;
        emit WhitelistedContractAdded(tokenContract);
    }

    function removeWhitelistedContract(
        address tokenContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete whitelistedContracts[tokenContract];
        emit WhitelistedContractRemoved(tokenContract);
    }

    function lockERC1155(
        address tokenContract,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external onlyWhitelisted(tokenContract) nonReentrant whenNotPaused {
        require(
            tokenIds.length == amounts.length,
            "tokenIds length does not match amounts length"
        );
        IERC1155(tokenContract).safeBatchTransferFrom(
            msg.sender,
            address(this),
            tokenIds,
            amounts,
            "0x00"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            lockedERC1155Tokens[tokenContract][tokenIds[i]] =
                lockedERC1155Tokens[tokenContract][tokenIds[i]] +
                amounts[i];
        }
        emit ERC1155Locked(msg.sender, tokenContract, tokenIds, amounts);
    }

    function burnERC721(
        address tokenContract,
        uint256[] calldata tokenIds
    )
        external
        onlyBurnableWhitelisted(tokenContract)
        nonReentrant
        whenNotPaused
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(tokenContract).burn(tokenIds[i]);
        }
        emit ERC721Burnt(msg.sender, tokenContract, tokenIds);
    }

    function withdrawERC1155(
        address tokenContract,
        address withdrawer,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external nonReentrant whenNotPaused onlyRole(WITHDRAW_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                lockedERC1155Tokens[tokenContract][tokenIds[i]] >= amounts[i],
                "Token is not locked"
            );
        }
        //add lazy mint here
        IERC1155(tokenContract).safeBatchTransferFrom(
            address(this),
            msg.sender,
            tokenIds,
            amounts,
            "0x00"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            lockedERC1155Tokens[tokenContract][tokenIds[i]] - amounts[i];
        }
        emit NFTWithdraw(withdrawer, tokenContract, tokenIds, amounts);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
