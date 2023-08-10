// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICraftSpiceToken.sol";
import "./Utilities/EIP712CSDecoder.sol";

contract LazyCSMinter is EIP712Decoder, ReentrancyGuard {
    address public adminAddress;
    mapping(bytes16 => bool) public idUsed;
    ICraftSpiceToken public csToken;

    string private constant EIP712_DOMAIN =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked(EIP712_DOMAIN));

    constructor(ICraftSpiceToken _csToken, address _adminAddress) {
        require(address(_csToken) != address(0), "No Zero Address");
        csToken = _csToken;
        adminAddress = _adminAddress;
    }

    function lazyMint(
        SignedCSVoucher calldata signedCSVoucher
    ) public nonReentrant {
        require(!idUsed[signedCSVoucher.message.id], "voucher had been used");
        bool verifiedAddress = verifySignedCSVoucher(signedCSVoucher) ==
            adminAddress;
        require(verifiedAddress, "Invalid signature");
        csToken.claim(
            signedCSVoucher.message.minter,
            signedCSVoucher.message.amount
        );
        // set id used as true
        idUsed[signedCSVoucher.message.id] = true;
    }

    function getDomainHash() public view virtual override returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("LazyCS-Voucher"),
                keccak256("1"),
                chainId,
                address(this)
            )
        );
        return DOMAIN_SEPARATOR;
    }

    function setAdminAddress(address _adminAddress) public {
        require(adminAddress == msg.sender, "access required");
        adminAddress = _adminAddress;
    }
}
