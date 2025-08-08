// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";

import {IABIResolver} from "ens-contracts/resolvers/profiles/IABIResolver.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {IContentHashResolver} from "ens-contracts/resolvers/profiles/IContentHashResolver.sol";
import {IDNSRecordResolver} from "ens-contracts/resolvers/profiles/IDNSRecordResolver.sol";
import {IDNSZoneResolver} from "ens-contracts/resolvers/profiles/IDNSZoneResolver.sol";
import {IInterfaceResolver} from "ens-contracts/resolvers/profiles/IInterfaceResolver.sol";
import {IMulticallable} from "ens-contracts/resolvers/IMulticallable.sol";
import {INameResolver} from "ens-contracts/resolvers/profiles/INameResolver.sol";
import {IPubkeyResolver} from "ens-contracts/resolvers/profiles/IPubkeyResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";
import {IExtendedResolver} from "ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {IVersionableResolver} from "ens-contracts/resolvers/profiles/IVersionableResolver.sol";

contract SupportsInterface is UpgradeableL2ResolverBase {
    function test_supportsABIResolver() public view {
        assertTrue(resolver.supportsInterface(type(IABIResolver).interfaceId));
    }

    function test_supportsAddrResolver() public view {
        assertTrue(resolver.supportsInterface(type(IAddrResolver).interfaceId));
    }

    function test_supportsContentHashResolver() public view {
        assertTrue(resolver.supportsInterface(type(IContentHashResolver).interfaceId));
    }

    function test_supportsDNSRecordResolver() public view {
        assertTrue(resolver.supportsInterface(type(IDNSRecordResolver).interfaceId));
    }

    function test_supportsDNSZoneResolver() public view {
        assertTrue(resolver.supportsInterface(type(IDNSZoneResolver).interfaceId));
    }

    function test_supportsInterfaceResolver() public view {
        assertTrue(resolver.supportsInterface(type(IInterfaceResolver).interfaceId));
    }

    function test_supportsMulticallable() public view {
        assertTrue(resolver.supportsInterface(type(IMulticallable).interfaceId));
    }

    function test_supportsNameResolver() public view {
        assertTrue(resolver.supportsInterface(type(INameResolver).interfaceId));
    }

    function test_supportsPubkeyResolver() public view {
        assertTrue(resolver.supportsInterface(type(IPubkeyResolver).interfaceId));
    }

    function test_supportsTextResolver() public view {
        assertTrue(resolver.supportsInterface(type(ITextResolver).interfaceId));
    }

    function test_supportsExtendedResolver() public view {
        assertTrue(resolver.supportsInterface(type(IExtendedResolver).interfaceId));
    }

    function test_supportsVersionableResolver() public view {
        assertTrue(resolver.supportsInterface(type(IVersionableResolver).interfaceId));
    }
}
