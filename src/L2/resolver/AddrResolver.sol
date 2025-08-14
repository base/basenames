// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {IAddressResolver} from "ens-contracts/resolvers/profiles/IAddressResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title Address Resolver
///
/// @notice ENSIP-11 compliant Address Resolver. Adaptation of the ENS AddrResolver.sol profile contract, with
///         EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/AddrResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract AddrResolver is IAddrResolver, IAddressResolver, ResolverBase {
    struct AddrResolverStorage {
        /// @notice Address record per cointype, node and version.
        mapping(uint64 version => mapping(bytes32 node => mapping(uint256 cointype => bytes addr)))
            versionable_addresses;
    }

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("addr.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant ADDR_RESOLVER_STORAGE = 0x1871a91a9a944f867849820431bb11c2d1625edae573523bceb5b38b8b8a7500;

    /// @notice Ethereum chain id.
    uint32 constant CHAIN_ID_ETH = 1;

    /// @notice Ethereum mainnet network-as-cointype.
    uint256 private constant COIN_TYPE_ETH = 60;

    /// @notice EVM default cointype per ENSIP-19.
    uint256 constant COIN_TYPE_DEFAULT = 1 << 31; // 0x8000_0000

    /// @notice Thrown when an invalid bytes length is detected.
    error InvalidBytesLength();

    /// @notice Thrown when setting an invalid EVM address for a valid EVM cointype.
    error InvalidEVMAddress(bytes a);

    /// @notice Sets the address associated with an ENS node.
    ///
    /// @dev May only be called by the owner of that node in the ENS registry.
    ///
    /// @param node The node to update.
    /// @param a The address to set.
    function setAddr(bytes32 node, address a) external virtual authorized(node) {
        setAddr(node, COIN_TYPE_ETH, addressToBytes(a));
    }

    /// @notice Set the network or coin-specific address for an ENS `node`.
    ///
    /// @param node The ENS node to update.
    /// @param coinType The coinType for this address.
    /// @param a The network-agnostic bytes of the address.
    function setAddr(bytes32 node, uint256 coinType, bytes memory a) public virtual authorized(node) {
        if (a.length != 0 && a.length != 20 && isEVMCoinType(coinType)) {
            revert InvalidEVMAddress(a);
        }
        emit AddressChanged(node, coinType, a);
        if (coinType == COIN_TYPE_ETH) {
            emit AddrChanged(node, address(bytes20(a)));
        }
        _getAddrResolverStorage().versionable_addresses[_getResolverBaseStorage().recordVersions[node]][node][coinType]
        = a;
    }

    /// @notice Returns the address associated with a specified ENS `node`.
    ///
    /// @dev Returns the `addr` record for the Ethereum Mainnet network-as-cointype.
    ///
    /// @param node The ENS node to query.
    ///
    /// @return The associated address.
    function addr(bytes32 node) public view virtual override returns (address payable) {
        bytes memory a = addr(node, COIN_TYPE_ETH);
        if (a.length == 0) {
            return payable(0);
        }
        return bytesToAddress(a);
    }

    /// @notice Returns the address of the `node` for a specified `coinType`.
    ///
    /// @dev Complies with ENSIP-9, ENSIP-11 and ENSIP-19.
    ///     Will return `default` address if there is no address set for a specific EVM cointype.
    ///
    /// @param node The ENS node to update.
    /// @param coinType The coinType to fetch.
    ///
    /// @return addressBytes The address of the specified `node` for the specified `coinType`.
    function addr(bytes32 node, uint256 coinType) public view virtual override returns (bytes memory addressBytes) {
        mapping(uint256 coinType => bytes addr) storage addrs =
            _getAddrResolverStorage().versionable_addresses[_getResolverBaseStorage().recordVersions[node]][node];
        addressBytes = addrs[coinType];
        if (addressBytes.length == 0 && chainFromCoinType(coinType) > 0) {
            addressBytes = addrs[COIN_TYPE_DEFAULT];
        }
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IAddrResolver).interfaceId || interfaceID == type(IAddressResolver).interfaceId
            || super.supportsInterface(interfaceID);
    }

    /// @notice Helper to convert bytes into an EVM address object.
    function bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        if (b.length != 20) revert InvalidBytesLength();
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    /// @notice Helper to convert an EVM address to a bytes` object.
    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }

    /// @notice Fetch the uint32 coinType from an EVM coinType.
    ///
    /// @dev Extract Chain ID from `coinType`.
    ///
    /// @param coinType The coin type.
    ///
    /// @return The Chain ID or 0 if non-EVM Chain.
    function chainFromCoinType(uint256 coinType) internal pure returns (uint32) {
        if (coinType == COIN_TYPE_ETH) return CHAIN_ID_ETH;
        coinType ^= COIN_TYPE_DEFAULT;
        return uint32(coinType < COIN_TYPE_DEFAULT ? coinType : 0);
    }

    /// @notice Determine if `coinType` is for an EVM address.
    ///
    /// @param coinType The network as a coinType.
    ///
    /// @return `true` if coinType represents an EVM address, else `false`.
    function isEVMCoinType(uint256 coinType) internal pure returns (bool) {
        return coinType == COIN_TYPE_DEFAULT || chainFromCoinType(coinType) > 0;
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getAddrResolverStorage() internal pure returns (AddrResolverStorage storage $) {
        assembly {
            $.slot := ADDR_RESOLVER_STORAGE
        }
    }
}
