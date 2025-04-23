//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IReverseRegistrar} from "./interface/IReverseRegistrar.sol";
import {IL2ReverseRegistrar} from "./interface/IL2ReverseRegistrar.sol";

/// @title ReverseRegistrarShim
///
/// @notice A temporary shim contract used to ensure user data is not lost while migrating into ENSIP-19 compliance.
///         The contract writes reverse records to both the legacy ReverseRegistrar and the new ENS-deployed
///         L2ReverseRegistrar.
///
/// @author Coinbase (https://github.com/base/basenames)
contract ReverseRegistrarShim {
    /// @notice The address of the legacy Basenames ReverseRegistrar contract.
    address public immutable reverseRegistrar;
    /// @notice The address of the ENS-deployed L2ReverseRegistrar contract.
    address public immutable l2ReverseRegistrar;
    /// @notice The address of the Basenames public resolver.
    address public immutable l2Resolver;

    /// @notice constructor.
    constructor(address reverseRegistrar_, address l2ReverseRegistrar_, address l2Resolver_) {
        reverseRegistrar = reverseRegistrar_;
        l2ReverseRegistrar = l2ReverseRegistrar_;
        l2Resolver = l2Resolver_;
    }

    /// @notice Sets the reverse record `name` for `addr`.
    ///
    /// @dev First calls the ENS L2ReverseRegistrar and sets the name-record for the provided address. Then calls the legacy
    ///     Basenames reverse registrar and registers the name there as well.
    ///
    /// @param addr The name records will be set for this address.
    /// @param name The name that will be stored for `addr`.
    /// @param signatureExpiry The timestamp expiration of the signature.
    /// @param cointypes The array of networks-as-cointypes used in replayable reverse sets.
    /// @param signature The signature bytes.
    function setNameForAddrWithSignature(
        address addr,
        string calldata name,
        uint256 signatureExpiry,
        uint256[] memory cointypes,
        bytes memory signature
    ) external returns (bytes32) {
        IL2ReverseRegistrar(l2ReverseRegistrar).setNameForAddrWithSignature(
            addr, signatureExpiry, name, cointypes, signature
        );
        return IReverseRegistrar(reverseRegistrar).setNameForAddr(addr, msg.sender, l2Resolver, name);
    }
}
