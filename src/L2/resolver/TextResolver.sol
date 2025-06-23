// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title Text Resolver
///
/// @notice ENSIP-5 compliant Text Resolver. Adaptation of the ENS TextResolver.sol profile contract, with
///         EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/TextResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract TextResolver is ITextResolver, ResolverBase {
    struct TextResolverStorage {
        /// @notice Text value by text key, node, and version.
        mapping(uint64 version => mapping(bytes32 node => mapping(string text_key => string text_value)))
            versionable_texts;
    }

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("text.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant TEXT_RESOLVER_STORAGE = 0x0795ed949e6fff5efdc94a1021939889222c7fb041954dcfee28c913f2af9200;

    /// @notice Sets the text data associated with an ENS node and key.
    ///
    /// @param node The node to update.
    /// @param key The key to set.
    /// @param value The text data value to set.
    function setText(bytes32 node, string calldata key, string calldata value) external virtual authorized(node) {
        _getTextResolverStorage().versionable_texts[_getResolverBaseStorage().recordVersions[node]][node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /// @notice Returns the text data associated with an ENS node and key.
    ///
    /// @param node The ENS node to query.
    /// @param key The text data key to query.
    ///
    /// @return The associated text data.
    function text(bytes32 node, string calldata key) external view virtual override returns (string memory) {
        return _getTextResolverStorage().versionable_texts[_getResolverBaseStorage().recordVersions[node]][node][key];
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(ITextResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getTextResolverStorage() internal pure returns (TextResolverStorage storage $) {
        assembly {
            $.slot := TEXT_RESOLVER_STORAGE
        }
    }
}
