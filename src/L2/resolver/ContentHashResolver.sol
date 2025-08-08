// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IContentHashResolver} from "ens-contracts/resolvers/profiles/IContentHashResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title Content Hash Resolver
///
/// @notice ENSIP-7 compliant Content Hash Resolver profile. Adaptation of the ENS ContentHashResolver.sol profile contract,
///         with EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/ContentHashResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract ContentHashResolver is IContentHashResolver, ResolverBase {
    struct ContentHashResolverStorage {
        /// @notice Content hashes by node and version.
        mapping(uint64 version => mapping(bytes32 node => bytes contenthash)) versionable_hashes;
    }

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("content.hash.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant CONTENT_HASH_RESOLVER_STORAGE =
        0x3cead3a342b450f6c566db8bcc5888396a4bada4d226d84f6075be8f3245c100;

    /// @notice Sets the contenthash associated with an ENS node.
    ///
    /// @dev May only be called by the owner of that node in the ENS registry.
    ///
    /// @param node The node to update.
    /// @param hash The contenthash to set
    function setContenthash(bytes32 node, bytes calldata hash) external virtual authorized(node) {
        _getContentHashResolverStorage().versionable_hashes[_getResolverBaseStorage().recordVersions[node]][node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /// @notice Returns the contenthash associated with an ENS node.
    ///
    /// @param node The ENS node to query.
    ///
    /// @return The associated contenthash.
    function contenthash(bytes32 node) external view virtual override returns (bytes memory) {
        return _getContentHashResolverStorage().versionable_hashes[_getResolverBaseStorage().recordVersions[node]][node];
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IContentHashResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getContentHashResolverStorage() internal pure returns (ContentHashResolverStorage storage $) {
        assembly {
            $.slot := CONTENT_HASH_RESOLVER_STORAGE
        }
    }
}
