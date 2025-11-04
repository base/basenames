//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {SybilResistanceVerifier} from "src/lib/SybilResistanceVerifier.sol";

import {SignatureDiscountValidator} from "src/L2/discounts/SignatureDiscountValidator.sol";

contract SignatureDiscountValidatorBase is Test {
    address public owner = makeAddr("owner");
    address public signer;
    uint256 public signerPk;
    address public user = makeAddr("user");
    uint64 time = 1717200000;
    uint64 expires = 1893456000;

    SignatureDiscountValidator validator;

    function setUp() public {
        vm.warp(time);
        (signer, signerPk) = makeAddrAndKey("signer");

        validator = new SignatureDiscountValidator(owner, signer);
    }

    function _getDefaultValidationData() internal virtual returns (bytes memory) {
        bytes32 digest = SybilResistanceVerifier._makeSignatureHash(address(validator), signer, user, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        return abi.encode(user, expires, sig);
    }

    function test_constructor() public {
        vm.expectRevert(SignatureDiscountValidator.NoZeroAddress.selector);
        new SignatureDiscountValidator(address(0), signer);

        vm.expectRevert(SignatureDiscountValidator.NoZeroAddress.selector);
        new SignatureDiscountValidator(owner, address(0));
    }
}
