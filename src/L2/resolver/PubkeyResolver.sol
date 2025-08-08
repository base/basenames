// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPubkeyResolver} from "ens-contracts/resolvers/profiles/IPubkeyResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title Pubkey Resolver
///
/// @notice Adaptation of the ENS PubkeyResolver.sol profile contract, with EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/PubkeyResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract PubkeyResolver is IPubkeyResolver, ResolverBase {
    /// @notice Tuple containing the x and y coordinates of a public key.
    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    struct PubkeyResolverStorage {
        /// @notice Public keys by node and version.
        mapping(uint64 version => mapping(bytes32 node => PublicKey pubkey)) versionable_pubkeys;
    }

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("pubkey.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant PUBKEY_RESOLVER_STORAGE = 0x59a318c6a4da81295c2a32b42a02c3db057bb9422e2eb1f6e516ee3694b1ef00;

    /// @notice Sets the SECP256k1 public key associated with an ENS node.
    ///
    /// @param node The ENS node to query.
    ///
    /// @param x the X coordinate of the curve point for the public key.
    /// @param y the Y coordinate of the curve point for the public key.
    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external virtual authorized(node) {
        _getPubkeyResolverStorage().versionable_pubkeys[_getResolverBaseStorage().recordVersions[node]][node] =
            PublicKey(x, y);
        emit PubkeyChanged(node, x, y);
    }

    /// @notice Returns the SECP256k1 public key associated with an ENS node.
    ///
    /// @dev See EIP-619.
    ///
    /// @param node The ENS node to query.
    ///
    /// @return x The X coordinate of the curve point for the public key.
    /// @return y The Y coordinate of the curve point for the public key.
    function pubkey(bytes32 node) external view virtual override returns (bytes32 x, bytes32 y) {
        uint64 currentRecordVersion = _getResolverBaseStorage().recordVersions[node];
        PubkeyResolverStorage storage $ = _getPubkeyResolverStorage();
        return
            ($.versionable_pubkeys[currentRecordVersion][node].x, $.versionable_pubkeys[currentRecordVersion][node].y);
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IPubkeyResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getPubkeyResolverStorage() internal pure returns (PubkeyResolverStorage storage $) {
        assembly {
            $.slot := PUBKEY_RESOLVER_STORAGE
        }
    }
}
