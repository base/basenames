//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {TBADiscountValidator} from "src/L2/discounts/TBADiscountValidator.sol";

contract TBADiscountValidatorBase is Test {
    TBADiscountValidator validator;

    address public user = makeAddr("user");
    address public signer;
    uint256 public signerPk;
    bytes32 deviceId;

    uint64 time = 1717200000;
    uint64 expires = 1893456000;

    function setUp() public {
        vm.warp(time);
        (signer, signerPk) = makeAddrAndKey("signer");
        deviceId = keccak256("device");
        validator = new TBADiscountValidator(signer);
    }

    function _getDefaultValidationData() internal virtual returns (bytes memory) {
        bytes32 digest = _makeSignatureHash(user, deviceId, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        return abi.encode(deviceId, expires, sig);
    }

    function _makeSignatureHash(address claimer, bytes32 deviceId_, uint64 expires_) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1900", address(validator), claimer, deviceId_, expires_));
    }
}
