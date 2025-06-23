// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BytesUtils, RRUtils} from "ens-contracts/dnssec-oracle/RRUtils.sol";
import {IDNSRecordResolver} from "ens-contracts/resolvers/profiles/IDNSRecordResolver.sol";
import {IDNSZoneResolver} from "ens-contracts/resolvers/profiles/IDNSZoneResolver.sol";

import {ResolverBase} from "./ResolverBase.sol";

/// @title DNS Resolver
///
/// @notice ENSIP-6 compliant DNS Resolver profile. Adaptation of the ENS DNSResolver.sol profile contract,
///         with EIP-7201 storage compliance.
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/DNSResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
abstract contract DNSResolver is IDNSRecordResolver, IDNSZoneResolver, ResolverBase {
    using RRUtils for *;
    using BytesUtils for bytes;

    struct DNSResolverStorage {
        /// @notice Zone hashes for the domains.
        //      A zone hash is an EIP-1577 content hash in binary format that should point to a
        //      resource containing a single zonefile.
        mapping(uint64 version => mapping(bytes32 node => bytes zonehash)) versionable_zonehashes;
        /// @notice The records themselves, stored as binary RRSETs
        mapping(
            uint64 version
                => mapping(bytes32 node => mapping(bytes32 namehash => mapping(uint16 resource => bytes data)))
        ) versionable_records;
        /// @notice Count of number of entries for a given name.  Required for DNS resolvers
        //      when resolving wildcards.
        mapping(uint64 version => mapping(bytes32 node => mapping(bytes32 namehash => uint16 count)))
            versionable_nameEntriesCount;
    }

    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("dns.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant DNS_RESOLVER_STORAGE = 0x563d533dd0798ef1806840ff9a36667f1ac5e6f948db03cf7022b575f40ccd00;

    /// @notice Set one or more DNS records.  Records are supplied in wire-format.
    ///
    /// @dev Records with the same node/name/resource must be supplied one after the
    ///     other to ensure the data is updated correctly. For example, if the data
    ///     was supplied:
    ///         a.example.com IN A 1.2.3.4
    ///         a.example.com IN A 5.6.7.8
    ///         www.example.com IN CNAME a.example.com.
    ///     then this would store the two A records for a.example.com correctly as a
    ///     single RRSET, however if the data was supplied:
    ///         a.example.com IN A 1.2.3.4
    ///         www.example.com IN CNAME a.example.com.
    ///         a.example.com IN A 5.6.7.8
    ///     then this would store the first A record, the CNAME, then the second A
    ///     record which would overwrite the first.
    ///
    /// @param node the namehash of the node for which to set the records
    /// @param data the DNS wire format records to set
    function setDNSRecords(bytes32 node, bytes calldata data) external virtual authorized(node) {
        uint16 resource = 0;
        uint256 offset = 0;
        bytes memory name;
        bytes memory value;
        bytes32 nameHash;
        uint64 version = _getResolverBaseStorage().recordVersions[node];
        // Iterate over the data to add the resource records
        for (RRUtils.RRIterator memory iter = data.iterateRRs(0); !iter.done(); iter.next()) {
            if (resource == 0) {
                resource = iter.dnstype;
                name = iter.name();
                nameHash = keccak256(abi.encodePacked(name));
                value = bytes(iter.rdata());
            } else {
                bytes memory newName = iter.name();
                if (resource != iter.dnstype || !name.equals(newName)) {
                    setDNSRRSet(node, name, resource, data, offset, iter.offset - offset, value.length == 0, version);
                    resource = iter.dnstype;
                    offset = iter.offset;
                    name = newName;
                    nameHash = keccak256(name);
                    value = bytes(iter.rdata());
                }
            }
        }
        if (name.length > 0) {
            setDNSRRSet(node, name, resource, data, offset, data.length - offset, value.length == 0, version);
        }
    }

    /// @notice Obtain a DNS record.
    ///
    /// @param node The namehash of the node for which to fetch the record.
    /// @param name The keccak-256 hash of the fully-qualified name for which to fetch the record.
    /// @param resource The ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types.
    ///
    /// @return The DNS record in wire format if present, otherwise empty.
    function dnsRecord(bytes32 node, bytes32 name, uint16 resource)
        external
        view
        virtual
        override
        returns (bytes memory)
    {
        return _getDNSResolverStorage().versionable_records[_getResolverBaseStorage().recordVersions[node]][node][name][resource];
    }

    /// @notice Check if a given node has records.
    ///
    /// @param node The namehash of the node for which to check the records.
    /// @param name The keccak-256 hash of the fully-qualified name for which to fetch the record.
    ///
    /// @return `True` if records are stored for this node + name, else `False`.
    function hasDNSRecords(bytes32 node, bytes32 name) external view virtual returns (bool) {
        return (
            _getDNSResolverStorage().versionable_nameEntriesCount[_getResolverBaseStorage().recordVersions[node]][node][name]
                != 0
        );
    }

    /// @notice Sets the hash for the zone.
    ///
    /// @param node The node to update.
    /// @param hash The zonehash to set.
    function setZonehash(bytes32 node, bytes calldata hash) external virtual authorized(node) {
        uint64 currentRecordVersion = _getResolverBaseStorage().recordVersions[node];
        DNSResolverStorage storage $ = _getDNSResolverStorage();
        bytes memory oldhash = $.versionable_zonehashes[currentRecordVersion][node];
        $.versionable_zonehashes[currentRecordVersion][node] = hash;
        emit DNSZonehashChanged(node, oldhash, hash);
    }

    /// @notice Obtains the hash for the zone.
    ///
    /// @param node The ENS node to query.
    ///
    /// @return The associated zonehash.
    function zonehash(bytes32 node) external view virtual override returns (bytes memory) {
        return _getDNSResolverStorage().versionable_zonehashes[_getResolverBaseStorage().recordVersions[node]][node];
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IDNSRecordResolver).interfaceId || interfaceID == type(IDNSZoneResolver).interfaceId
            || super.supportsInterface(interfaceID);
    }

    /// @notice Internal helper for RRSet.
    function setDNSRRSet(
        bytes32 node,
        bytes memory name,
        uint16 resource,
        bytes memory data,
        uint256 offset,
        uint256 size,
        bool deleteRecord,
        uint64 version
    ) private {
        bytes32 nameHash = keccak256(name);
        bytes memory rrData = data.substring(offset, size);
        DNSResolverStorage storage $ = _getDNSResolverStorage();
        if (deleteRecord) {
            if ($.versionable_records[version][node][nameHash][resource].length != 0) {
                $.versionable_nameEntriesCount[version][node][nameHash]--;
            }
            delete ($.versionable_records[version][node][nameHash][resource]);
            emit DNSRecordDeleted(node, name, resource);
        } else {
            if ($.versionable_records[version][node][nameHash][resource].length == 0) {
                $.versionable_nameEntriesCount[version][node][nameHash]++;
            }
            $.versionable_records[version][node][nameHash][resource] = rrData;
            emit DNSRecordChanged(node, name, resource, rrData);
        }
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getDNSResolverStorage() internal pure returns (DNSResolverStorage storage $) {
        assembly {
            $.slot := DNS_RESOLVER_STORAGE
        }
    }
}
