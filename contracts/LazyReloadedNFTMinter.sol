// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Utilities/EIP712MintReloadedNFTDecoder.sol";
import "./interfaces/IReloadedNFT.sol";

contract LazyReloadedNFTMinter is EIP712Decoder, Ownable, ReentrancyGuard {
    address public adminAddress;
    mapping(bytes16 => bool) public idUsed;
    IReloadedNFT public reloadedNFT;

    string private constant EIP712_DOMAIN =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked(EIP712_DOMAIN));

    constructor(IReloadedNFT _reloadedNFT, address _adminAddress) {
        require(
            address(_reloadedNFT) != address(0) &&
                address(_adminAddress) != address(0),
            "No Zero Address"
        );
        reloadedNFT = _reloadedNFT;
        adminAddress = _adminAddress;
    }

    function lazyMint(
        SignedMintBatchVoucher calldata signedMintBatchVoucher
    ) public nonReentrant {
        require(
            !idUsed[signedMintBatchVoucher.message.voucherId],
            "voucher had been used"
        );

        bool verifiedAddress = verifySignedMintBatchVoucher(
            signedMintBatchVoucher
        ) == adminAddress;
        require(verifiedAddress, "Invalid signature");

        reloadedNFT.mintBatch(
            signedMintBatchVoucher.message.to,
            signedMintBatchVoucher.message.tokenIds,
            signedMintBatchVoucher.message.amounts,
            signedMintBatchVoucher.message.data
        );
        idUsed[signedMintBatchVoucher.message.voucherId] = true;
    }

    function getDomainHash() public view virtual override returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("Lazymint-ReloadedNFT"),
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
