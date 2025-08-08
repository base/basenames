// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IABIResolver} from "ens-contracts/resolvers/profiles/IABIResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title ABI Resolver
///
/// @notice ENSIP-4 compliant ABI Resolver. Adaptation of the ENS ABIResolver.sol profile contract, with
///         EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/ABIResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract ABIResolver is IABIResolver, ResolverBase {
    struct ABIResolverStorage {
        /// @notice ABI record (`bytes`) by content type, node, and version.
        mapping(uint64 version => mapping(bytes32 node => mapping(uint256 contentType => bytes data))) versionable_abis;
    }

    /// @notice Thrown when setting an ABI with an invalid content type.
    error InvalidContentType();

    /// @notice EIP-7201 storage location.
    /// keccak256(abi.encode(uint256(keccak256("abi.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ABI_RESOLVER_STORAGE = 0x76dc89e1c49d3cda8f11a131d381f3dbd0df1919a4e1a669330a2763d2821400;

    /// @notice Sets the ABI associated with an ENS node.
    ///
    /// @dev Nodes may have one ABI of each content type. To remove an ABI, set it to
    ///     the empty string.
    ///
    /// @param node The node to update.
    /// @param contentType The content type of the ABI.
    /// @param data The ABI data.
    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external virtual authorized(node) {
        // Content types must be powers of 2
        if (((contentType - 1) & contentType) != 0) revert InvalidContentType();

        _getABIResolverStorage().versionable_abis[_getResolverBaseStorage().recordVersions[node]][node][contentType] =
            data;
        emit ABIChanged(node, contentType);
    }

    /// @notice Returns the ABI associated with an ENS node for a specific content type.
    ///
    /// @param node The ENS node to query.
    /// @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
    ///
    /// @return contentType The content type of the return value.
    /// @return data The ABI data.
    function ABI(bytes32 node, uint256 contentTypes) external view virtual override returns (uint256, bytes memory) {
        mapping(uint256 => bytes) storage abiset =
            _getABIResolverStorage().versionable_abis[_getResolverBaseStorage().recordVersions[node]][node];

        for (uint256 contentType = 1; contentType <= contentTypes; contentType <<= 1) {
            if ((contentType & contentTypes) != 0 && abiset[contentType].length > 0) {
                return (contentType, abiset[contentType]);
            }
        }

        return (0, bytes(""));
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IABIResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getABIResolverStorage() internal pure returns (ABIResolverStorage storage $) {
        assembly {
            $.slot := ABI_RESOLVER_STORAGE
        }
    }
}
