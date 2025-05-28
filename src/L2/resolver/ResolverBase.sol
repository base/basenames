// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IVersionableResolver} from "ens-contracts/resolvers/profiles/IVersionableResolver.sol";

abstract contract ResolverBase is ERC165, IVersionableResolver {
    struct ResolverBaseStorage {
        mapping(bytes32 node => uint64 version) recordVersions;
    }

    error NotAuthorized(bytes32 node, address caller);

    // keccak256(abi.encode(uint256(keccak256("resolver.base.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RESOLVER_BASE_LOCATION = 0x421bc1b234e222da5ef3c41832b689b450ae239e8b18cf3c05f5329ae7d99700;

    function isAuthorised(bytes32 node) internal view virtual returns (bool);

    modifier authorised(bytes32 node) {
        if (!isAuthorised(node)) revert NotAuthorized(node, msg.sender);
        _;
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function clearRecords(bytes32 node) public virtual authorised(node) {
        ResolverBaseStorage storage $ = _getResolverBaseStorage();
        $.recordVersions[node]++;
        emit VersionChanged(node, $.recordVersions[node]);
    }

    function recordVersions(bytes32 node) external view returns (uint64) {
        return _getResolverBaseStorage().recordVersions[node];
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IVersionableResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    function _getResolverBaseStorage() internal pure returns (ResolverBaseStorage storage $) {
        assembly {
            $.slot := RESOLVER_BASE_LOCATION
        }
    }
}
