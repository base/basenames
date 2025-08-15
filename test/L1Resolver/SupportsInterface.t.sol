//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

contract SupportsInterface is L1ResolverTestBase {
    function test_supportsExtendedResolver() public view {
        assertTrue(resolver.supportsInterface(bytes4(0x9061b923))); // https://docs.ens.domains/ensip/10
    }

    function test_supportsERC165() public view {
        assertTrue(resolver.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsForwarding_toIAddrCompliantRootResolver() public view {
        assertTrue(resolver.supportsInterface(type(IAddrResolver).interfaceId));
    }

    function test_supportsForwarding_toITextCompliantRootResolver() public view {
        assertTrue(resolver.supportsInterface(type(ITextResolver).interfaceId));
    }

    function test_doesNotSupportArbitraryInterfaceId(bytes4 interfaceID) public view {
        vm.assume(
            interfaceID != bytes4(0x9061b923) && interfaceID != type(IERC165).interfaceId
                && interfaceID != type(IAddrResolver).interfaceId && interfaceID != type(ITextResolver).interfaceId
        );
        assertFalse(resolver.supportsInterface(interfaceID));
    }
}
