// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Utilities/EIP712UnlockDecoder.sol";
import "./interfaces/ILockContract.sol";

contract LazyUnlock is EIP712Decoder, Ownable, ReentrancyGuard {
    address public adminAddress;
    mapping(uint256 => bool) public idUsed;
    ILockContract public lockContract;

    string private constant EIP712_DOMAIN =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked(EIP712_DOMAIN));

    constructor(ILockContract _lockContract, address _adminAddress) {
        require(
            address(_lockContract) != address(0) &&
                address(_adminAddress) != address(0),
            "No Zero Address"
        );
        lockContract = _lockContract;
        adminAddress = _adminAddress;
    }

    function lazyMint(
        SignedUnlockVoucher calldata signedUnlockVoucher
    ) public nonReentrant {
        require(
            !idUsed[signedUnlockVoucher.message.voucherId],
            "voucher had been used"
        );
        bool verifiedAddress = verifySignedUnlockVoucher(signedUnlockVoucher) ==
            adminAddress;
        require(verifiedAddress, "Invalid signature");
        lockContract.withdrawERC1155(
            signedUnlockVoucher.message.tokenContract,
            signedUnlockVoucher.message.withdrawer,
            signedUnlockVoucher.message.tokenIds,
            signedUnlockVoucher.message.amounts
        );
        idUsed[signedUnlockVoucher.message.voucherId] = true;
    }

    function getDomainHash() public view virtual override returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("Lazy-Unlock"),
                keccak256("1"),
                chainId,
                address(this)
            )
        );
        return DOMAIN_SEPARATOR;
    }

    function setAdminAddress(address _adminAddress) public onlyOwner {
        adminAddress = _adminAddress;
    }
}
