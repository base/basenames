// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IBaseRegistrar {
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event NameMigrated(uint256 indexed id, address indexed owner, uint256 expires);
    event NameRegistered(uint256 indexed id, address indexed owner, uint256 expires);
    event NameRenewed(uint256 indexed id, uint256 expires);

    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external;

    /// @notice Returns true if the specified name is available for registration.
    ///
    /// @param id The id of the name to check availability of.
    ///
    /// @return `true` if the name is available, else `false`.
    function isAvailable(uint256 id) external view returns (bool);

    // Revoke controller permission for an address.
    function removeController(address controller) external;

    // Set the resolver for the TLD this registrar manages.
    function setResolver(address resolver) external;

    // Returns the expiration timestamp of the specified label hash.
    function nameExpires(uint256 id) external view returns (uint256);

    // Returns true if the specified name is available for registration.
    function available(uint256 id) external view returns (bool);

    /**
     * @dev Register a name.
     */
    function register(uint256 id, address owner, uint256 duration) external returns (uint256);

    /// @notice Register a name and add details to the record in the Registry.
    ///
    /// @param id The token id determined by keccak256(label).
    /// @param owner The address that should own the registration.
    /// @param duration Duration in seconds for the registration.
    /// @param resolver Address of the resolver for the name.
    /// @param ttl Time-to-live for the name.
    function registerWithRecord(uint256 id, address owner, uint256 duration, address resolver, uint64 ttl)
        external
        returns (uint256);

    function renew(uint256 id, uint256 duration) external returns (uint256);

    /**
     * @dev Reclaim ownership of a name in ENS, if you own it in the registrar.
     */
    function reclaim(uint256 id, address owner) external;
}
