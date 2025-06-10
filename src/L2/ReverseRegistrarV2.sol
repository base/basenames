//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {IL2ReverseRegistrar} from "src/L2/interface/IL2ReverseRegistrar.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {Sha3} from "src/lib/Sha3.sol";

/// @title Reverse Registrar V2
///
/// @notice Registrar which allows registrants to establish a name as their "primary" record for reverse resolution.
///         Inspired by ENS's ReverseRegistrar implementation:
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/reverseRegistrar/ReverseRegistrar.sol
///         Writes records to the network-specific reverse node set on construction via `reverseNode`.
///         Compliant with ENSIP-19: https://docs.ens.domains/ensip/19
///
/// @author Coinbase (https://github.com/base/basenames)
contract ReverseRegistrarV2 is Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The Registry contract.
    ENS public immutable registry;

    /// @notice The reverse node this registrar manages.
    bytes32 public immutable reverseNode;

    /// @notice The address of the ENS-deployed L2ReverseRegistrar contract.
    address public immutable l2ReverseRegistrar;

    /// @notice The network cointype.
    uint256 public immutable cointype;

    /// @notice Permissioned controller contracts.
    mapping(address controller => bool approved) public controllers;

    /// @notice The default resolver for setting Name resolution records.
    address public defaultResolver;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERRORS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Thrown when `sender` is not authorized to modify records for `addr`.
    ///
    /// @param addr The `addr` that was being modified.
    /// @param sender The unauthorized sender.
    error NotAuthorized(address addr, address sender);

    /// @notice Thrown when trying to set the zero address as the default resolver.
    error NoZeroAddress();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted upon successfully establishing a base-specific reverse record.
    ///
    /// @param addr The address for which the the record was set.
    /// @param node  The namehashed node that was set as the base reverse record.
    event BaseReverseClaimed(address indexed addr, bytes32 indexed node);

    /// @notice Emitted when the default Resolver is changed by the `owner`.
    ///
    /// @param resolver The address of the new Resolver.
    event DefaultResolverChanged(address indexed resolver);

    /// @notice Emitted when a controller address approval status is changed by the `owner`.
    ///
    /// @param controller The address of the `controller`.
    /// @param approved The new approval state for the `controller` address.
    event ControllerApprovalChanged(address indexed controller, bool approved);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MODIFIERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Decorator for checking authorization status for a caller against a provided `addr`.
    ///
    /// @dev A caller is authorized to set the record for `addr` if they are one of:
    ///     1. The `addr` is the sender
    ///     2. The sender is an approved `controller`
    ///     3. The sender is an approved operator for `addr` on the registry
    ///     4. The sender is `Ownable:ownerOf()` for `addr`
    ///
    /// @param addr The `addr` that is being modified.
    modifier authorized(address addr) {
        if (
            addr != msg.sender && !controllers[msg.sender] && !registry.isApprovedForAll(addr, msg.sender)
                && !_ownsContract(addr)
        ) {
            revert NotAuthorized(addr, msg.sender);
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        IMPLEMENTATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice ReverseRegistrar construction.
    ///
    /// @param registry_ The ENS registry, will be stored as `registry`.
    /// @param owner_ The permissioned address initialized as the `owner` in the `Ownable` context.
    /// @param reverseNode_ The network-sepcific reverse node.
    /// @param cointype_ The network-specific cointype.
    constructor(ENS registry_, address owner_, bytes32 reverseNode_, address l2ReverseRegistrar_, uint256 cointype_) {
        _initializeOwner(owner_);
        registry = registry_;
        reverseNode = reverseNode_;
        l2ReverseRegistrar = l2ReverseRegistrar_;
        cointype = cointype_;
    }

    /// @notice Sets the reverse record `name` for `addr`.
    ///
    /// @dev First calls the ENS L2ReverseRegistrar and sets the name-record for the provided address. Then follows the legacy
    ///     Basenames reverse registrar flow. The call to the L2ReverseRegistrar will revert if the signature is invalid or
    ///     if the signature is expired.
    ///
    /// @param addr The name records will be set for this address.
    /// @param signatureExpiry The timestamp expiration of the signature.
    /// @param name The name that will be stored for `addr`.
    /// @param cointypes The array of networks-as-cointypes used in replayable reverse sets.
    /// @param signature The signature bytes.
    function setNameForAddrWithSignature(
        address addr,
        uint256 signatureExpiry,
        string calldata name,
        uint256[] memory cointypes,
        bytes memory signature
    ) external returns (bytes32) {
        IL2ReverseRegistrar(l2ReverseRegistrar).setNameForAddrWithSignature(
            addr, signatureExpiry, name, cointypes, signature
        );
        return setNameForAddr(addr, msg.sender, defaultResolver, name);
    }

    /// @notice Allows the owner to back populate the ENSIP-11 forward resolution records for basenames.
    ///
    /// @dev For each node in `nodes` we make a series of checks to make sure that we're
    ///     1. Trying to set data against our L2Resolver contract.
    ///     2. Setting a valid forward resolution address.
    ///     3. Not overwriting an existing value.
    ///     If any of these checks fails, we skip this node and continue.
    ///
    /// @param nodes The array of nodes for which records will be set.
    function setBaseForwardAddr(bytes32[] memory nodes) public onlyOwner {
        for (uint256 i; i < nodes.length; i++) {
            bytes32 _node = nodes[i];

            // Get the resolver address for the node and check that it is our public resolver.
            address resolverAddr = registry.resolver(_node);
            if (resolverAddr != defaultResolver) continue;
            AddrResolver resolver = AddrResolver(resolverAddr);

            // Get the `addr` record for the node and check validity.
            address resolvedAddr = resolver.addr(_node);
            if (resolvedAddr == address(0)) continue;

            // Check if there is an ENSIP-11 cointype address already set for this node.
            if (resolver.addr(_node, cointype).length != 0) continue;

            // Set the ENSIP-11 forward resolution addr.
            resolver.setAddr(_node, cointype, _addressToBytes(resolvedAddr));
        }
    }

    /// @notice Allows the owner to change the address of the default resolver.
    ///
    /// @dev The address of the new `resolver` must not be the zero address.
    ///     Emits `DefaultResolverChanged` after successfully storing `resolver` as `defaultResolver`.
    ///
    /// @param resolver The address of the new resolver.
    function setDefaultResolver(address resolver) public onlyOwner {
        if (address(resolver) == address(0)) revert NoZeroAddress();
        defaultResolver = resolver;
        registry.setResolver(reverseNode, resolver);
        emit DefaultResolverChanged(defaultResolver);
    }

    /// @notice Allows the owner to change the approval status of an address as a controller.
    ///
    /// @param controller The address of the controller.
    /// @param approved Whether the controller has permissions to modify reverse records.
    function setControllerApproval(address controller, bool approved) public onlyOwner {
        if (controller == address(0)) revert NoZeroAddress();
        controllers[controller] = approved;
        emit ControllerApprovalChanged(controller, approved);
    }

    /// @notice Transfers ownership of the base-specific reverse ENS record for `msg.sender` to the provided `owner`.
    ///
    /// @param owner The address to set as the owner of the reverse record in ENS.
    ///
    /// @return The ENS node hash of the base-specific reverse record.
    function claim(address owner) public returns (bytes32) {
        return claimForBaseAddr(msg.sender, owner, defaultResolver);
    }

    /// @notice Transfers ownership of the base-specific reverse ENS record for `addr` to the provided `owner`.
    ///
    /// @dev Restricted to only `authorized` owners/operators of `addr`.
    ///     Emits `BaseReverseClaimed` after successfully transfering ownership of the reverse record.
    ///
    /// @param addr The reverse record to set.
    /// @param owner The new owner of the reverse record in ENS.
    /// @param resolver The address of the resolver to set.
    ///
    /// @return The ENS node hash of the base-specific reverse record.
    function claimForBaseAddr(address addr, address owner, address resolver)
        public
        authorized(addr)
        returns (bytes32)
    {
        bytes32 labelHash = Sha3.hexAddress(addr);
        bytes32 baseReverseNode = keccak256(abi.encodePacked(reverseNode, labelHash));
        emit BaseReverseClaimed(addr, baseReverseNode);
        registry.setSubnodeRecord(reverseNode, labelHash, owner, resolver, 0);
        return baseReverseNode;
    }

    /// @notice Transfers ownership and sets the resolver of the reverse ENS record for `addr` to the provided `owner`.
    ///
    /// @param owner The address to set as the owner of the reverse record in ENS.
    /// @param resolver The address of the resolver to set.
    ///
    /// @return The ENS node hash of the base-specific reverse record.
    function claimWithResolver(address owner, address resolver) public returns (bytes32) {
        return claimForBaseAddr(msg.sender, owner, resolver);
    }

    /// @notice Set the `name()` record for the reverse ENS record associated with the calling account.
    ///
    /// @dev This call will first updates the resolver to the default reverse resolver if necessary.
    ///
    /// @param name The name to set for msg.sender.
    ///
    /// @return The ENS node hash of the reverse record.
    function setName(string memory name) public returns (bytes32) {
        return setNameForAddr(msg.sender, msg.sender, address(defaultResolver), name);
    }

    /// @notice Sets the `name()` record for the reverse ENS records associated with the `addr` provided.
    ///
    /// @dev Updates the resolver to a designated resolver. Only callable by `addr`'s `authroized` addresses.
    ///
    /// @param addr The reverse record to set.
    /// @param owner The owner of the reverse node.
    /// @param resolver The resolver of the reverse node.
    /// @param name The name to set for this address.
    ///
    /// @return The ENS node hash of the `baseAsCoinType.reverse` record.
    function setNameForAddr(address addr, address owner, address resolver, string memory name)
        public
        returns (bytes32)
    {
        bytes32 baseNode_ = claimForBaseAddr(addr, owner, resolver);
        NameResolver(resolver).setName(baseNode_, name);

        return baseNode_;
    }

    /// @notice Returns the node hash for a provided `addr`'s reverse records.
    ///
    /// @param addr The address to hash.
    ///
    /// @return The base-specific reverse node hash.
    function node(address addr) public view returns (bytes32) {
        return keccak256(abi.encodePacked(reverseNode, Sha3.hexAddress(addr)));
    }

    /// @notice Allows this contract to check if msg.sender is the `Ownable:owner()` for `addr`.
    ///
    /// @dev First checks if `addr` is a contract and returns early if not. Then uses a `try/except` to
    ///     see if `addr` responds with a valid address.
    ///
    /// @return `true` if the address returned from `Ownable:owner()` == msg.sender, else `false`.
    function _ownsContract(address addr) internal view returns (bool) {
        // Determine if a contract exists at `addr` and return early if not
        if (addr.code.length == 0) {
            return false;
        }
        // If a contract does exist, try and call `Ownable.owner()`
        try Ownable(addr).owner() returns (address owner) {
            return owner == msg.sender;
        } catch {
            return false;
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
