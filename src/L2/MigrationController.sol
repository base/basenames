// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/// @title Migration Controller
///
/// @notice Helper controller for migrating user address data from the vestigial `addr` space to the ENSIP-11 compliant
///     network-as-cointype format.
///
/// @author Coinbase (https://github.com/base/basenames)
contract MigrationController is Ownable2Step {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The Registry contract.
    ENS public immutable registry;

    /// @notice The ENSIP-11 network as coinType.
    uint256 public immutable coinType;

    /// @notice The legacy Basenames l2Resolver for setting Name resolution records.
    address public immutable l2Resolver;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        IMPLEMENTATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(ENS registry_, uint256 coinType_, address l2Resolver_, address owner_) Ownable(owner_) {
        registry = registry_;
        coinType = coinType_;
        l2Resolver = l2Resolver_;
    }

    /// @notice Allows the owner to back populate the ENSIP-11 forward resolution records for Basenames.
    ///
    /// @dev For each node in `nodes` we make a series of checks to make sure that we're
    ///     1. Trying to set data against our L2Resolver contract.
    ///     2. Setting a valid forward resolution address.
    ///     3. Not overwriting an existing value.
    ///     If any of these checks fails, we skip this node and continue.
    ///
    /// @param nodes The array of nodes for which records will be set.
    function setBaseForwardAddr(bytes32[] calldata nodes) public onlyOwner {
        uint256 length = nodes.length;
        for (uint256 i; i < length; i++) {
            bytes32 _node = nodes[i];

            // Get the resolver address for the node and check that it is our public resolver.
            address resolverAddr = registry.resolver(_node);
            if (resolverAddr != l2Resolver) continue;
            AddrResolver resolver = AddrResolver(resolverAddr);

            // Get the `addr` record for the node and check validity.
            address resolvedAddr = resolver.addr(_node);
            if (resolvedAddr == address(0)) continue;

            // Check if there is an ENSIP-11 cointype address already set for this node.
            if (resolver.addr(_node, coinType).length != 0) continue;

            // Set the ENSIP-11 forward resolution addr.
            resolver.setAddr(_node, coinType, _addressToBytes(resolvedAddr));
        }
    }

    /// @notice Helper for converting an address into a bytes object.
    ///
    /// @dev Copied from ENS `AddrResolver`:
    ///     https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/AddrResolver.sol
    ///
    /// @param a Address.
    function _addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
