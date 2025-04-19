// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";
import {ABIResolver} from "src/L2/resolver/ABIResolver.sol";

contract SetABI is UpgradeableL2ResolverBase {
    uint256 constant JSON_CONTENT = 1;
    uint256 constant ZLIB_JSON_CONTENT = 2;
    uint256 constant CBOR_CONTENT = 4;
    uint256 constant URI_CONTENT = 8;
    uint256 constant INVALID_CONTENT = 3;
    bytes data = "data";

    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.setABI(node, JSON_CONTENT, data);
    }

    function test_reverts_withInvalidContentType() public {
        vm.expectRevert(ABIResolver.InvalidContentType.selector);
        vm.prank(user);
        resolver.setABI(node, INVALID_CONTENT, data);
    }

    function test_setsTheABICorrectly_forJSONContent() public {
        vm.prank(user);
        resolver.setABI(node, JSON_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, JSON_CONTENT);
        _validateReturnedContent(retType, JSON_CONTENT, retData);
    }

    function test_setsTheABICorrectly_forZlibJSONContent() public {
        vm.prank(user);
        resolver.setABI(node, ZLIB_JSON_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, ZLIB_JSON_CONTENT);
        _validateReturnedContent(retType, ZLIB_JSON_CONTENT, retData);
    }

    function test_setsTheABICorrectly_forCBORContent() public {
        vm.prank(user);
        resolver.setABI(node, CBOR_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, CBOR_CONTENT);
        _validateReturnedContent(retType, CBOR_CONTENT, retData);
    }

    function test_setsTheABICorrectly_forURIContent() public {
        vm.prank(user);
        resolver.setABI(node, URI_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, URI_CONTENT);
        _validateReturnedContent(retType, URI_CONTENT, retData);
    }

    function test_doesNotRevertIfNotSet() public view {
        (uint256 retType, bytes memory retData) = resolver.ABI(node, JSON_CONTENT);
        _validateDefaultReturn(retType, retData);
    }

    function test_doesNotRevertIfIncompatible() public {
        vm.prank(user);
        resolver.setABI(node, URI_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, JSON_CONTENT);
        _validateDefaultReturn(retType, retData);
    }

    function test_canClearRecord() public {
        vm.startPrank(user);

        resolver.setABI(node, JSON_CONTENT, data);
        (uint256 retType, bytes memory retData) = resolver.ABI(node, JSON_CONTENT);
        _validateReturnedContent(retType, JSON_CONTENT, retData);

        resolver.clearRecords(node);
        (retType, retData) = resolver.ABI(node, JSON_CONTENT);
        _validateDefaultReturn(retType, retData);

        vm.stopPrank();
    }

    function _validateReturnedContent(uint256 retType, uint256 expectedType, bytes memory retData) internal view {
        assertEq(retType, expectedType);
        assertEq(keccak256(retData), keccak256(data));
    }

    function _validateDefaultReturn(uint256 retType, bytes memory retData) internal pure {
        assertEq(retType, 0);
        assertEq(retData, "");
    }
}
