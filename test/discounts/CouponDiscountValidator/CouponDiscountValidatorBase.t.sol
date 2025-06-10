//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CouponDiscountValidator} from "src/L2/discounts/CouponDiscountValidator.sol";

contract CouponDiscountValidatorBase is Test {
    CouponDiscountValidator validator;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public signer;
    uint256 public signerPk;
    bytes32 uuid;

    uint64 time = 1717200000;
    uint64 expires = 1893456000;

    function setUp() public {
        vm.warp(time);
        (signer, signerPk) = makeAddrAndKey("signer");
        uuid = keccak256("test_coupon");
        validator = new CouponDiscountValidator(owner, signer);
    }

    function _getDefaultValidationData() internal virtual returns (bytes memory) {
        bytes32 digest = _makeSignatureHash(user, uuid, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        return abi.encode(expires, uuid, sig);
    }

    function _makeSignatureHash(address claimer, bytes32 couponUuid, uint64 _expires) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1900", address(validator), signer, claimer, couponUuid, _expires));
    }
}
