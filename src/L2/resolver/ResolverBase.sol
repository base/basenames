// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IVersionableResolver} from "ens-contracts/resolvers/profiles/IVersionableResolver.sol";

/// @title Resolver Base
///
/// @notice Abstract schema with shared functionality used by all resolver profiles.
///     Inheriting contracts MUST implement the `isAuthorized` method.
abstract contract ResolverBase is ERC165, IVersionableResolver {
    struct ResolverBaseStorage {
        /// @notice Record version per node.
        mapping(bytes32 node => uint64 version) recordVersions;
    }

    /// @notice Thrown when an unauthorized caller tries to make changes to a node's records.
    error NotAuthorized(bytes32 node, address caller);

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("resolver.base.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RESOLVER_BASE_LOCATION = 0x421bc1b234e222da5ef3c41832b689b450ae239e8b18cf3c05f5329ae7d99700;

    /// @notice Decorator for record-write authorization checks.
    modifier authorized(bytes32 node) {
        if (!isAuthorized(node)) revert NotAuthorized(node, msg.sender);
        _;
    }

    /// @notice Increments the record version associated with an ENS node.
    ///
    /// @dev May only be called by the owner of that node in the ENS registry.
    ///
    /// @param node The node to update.
    function clearRecords(bytes32 node) external virtual authorized(node) {
        ResolverBaseStorage storage $ = _getResolverBaseStorage();
        $.recordVersions[node]++;
        emit VersionChanged(node, $.recordVersions[node]);
    }

    /// @notice Returns the current `version` of the `node`'s records.
    ///
    /// @param node The node to query for version.
    ///
    /// @return The version number.
    function recordVersions(bytes32 node) external view returns (uint64) {
        return _getResolverBaseStorage().recordVersions[node];
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IVersionableResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /// @notice Check whether the caller is authorized to edit records for `node`.
    ///
    /// @param node The node to check authorization against.
    ///
    /// @return `true` if msg.sender is authorized, else `false`.
    function isAuthorized(bytes32 node) internal view virtual returns (bool);

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getResolverBaseStorage() internal pure returns (ResolverBaseStorage storage $) {
        assembly {
            $.slot := RESOLVER_BASE_LOCATION
        }
    }
}
