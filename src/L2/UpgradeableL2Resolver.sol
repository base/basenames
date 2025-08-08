// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ExtendedResolver} from "ens-contracts/resolvers/profiles/ExtendedResolver.sol";
import {IExtendedResolver} from "ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {Multicallable} from "ens-contracts/resolvers/Multicallable.sol";
import {Ownable2StepUpgradeable} from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

import {ABIResolver} from "./resolver/ABIResolver.sol";
import {AddrResolver} from "./resolver/AddrResolver.sol";
import {ContentHashResolver} from "./resolver/ContentHashResolver.sol";
import {DNSResolver} from "./resolver/DNSResolver.sol";
import {InterfaceResolver} from "./resolver/InterfaceResolver.sol";
import {NameResolver} from "./resolver/NameResolver.sol";
import {PubkeyResolver} from "./resolver/PubkeyResolver.sol";
import {TextResolver} from "./resolver/TextResolver.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";

/// @title Upgradeable L2 Resolver
///
/// @notice The upgradeable public resolver for Basenames. This contract implements the functionality of the ENS
///         PublicResolver while also inheriting ExtendedResolver for compatibility with CCIP-read.
///         Public Resolver: https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/PublicResolver.sol
///         Extended Resolver: https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/ExtendedResolver.sol
///
/// @author Coinbase (https://github.com/base/basenames)
contract UpgradeableL2Resolver is
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    ExtendedResolver,
    InterfaceResolver,
    Multicallable,
    NameResolver,
    Ownable2StepUpgradeable,
    PubkeyResolver,
    TextResolver
{
    /// @notice EIP-7201 storage location.
    // keccak256(abi.encode(uint256(keccak256("resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RESOLVER_STORAGE_LOCATION =
        0xa75da70a48b778f6d7794a48ad897d5e41dff6abea13a6164e9a58efe57a7200;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct ResolverStorage {
        /// @notice The registry contract.
        ENS registry;
        /// @notice The reverse registrar contract.
        address reverseRegistrar;
        /// @notice The permissioned registrar controller contracts.
        mapping(address controller => bool isApproved) approvedControllers;
        /// @notice A mapping of operators per owner address. An operator is authorized to make changes to
        ///         all names owned by the `owner`.
        mapping(address owner => mapping(address operator => bool isApproved)) _operatorApprovals;
        /// @notice A mapping of delegates per owner per name (stored as a node). A delegate that is authorized
        ///         by an owner for a name may make changes to the name's resolver.
        mapping(address owner => mapping(bytes32 node => mapping(address delegate => bool isApproved))) _tokenApprovals;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERRORS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Thrown when msg.sender tries to set itself as an operator.
    error CantSetSelfAsOperator();

    /// @notice Thrown when msg.sender tries to set itself as a delegate for one of its names.
    error CantSetSelfAsDelegate();

    /// @notice Thrown when trying to set a contract address to the zero address.
    error NoZeroAddress();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when an operator is added or removed.
    ///
    /// @param owner The address of the owner of names.
    /// @param operator The address of the approved operator for the `owner`.
    /// @param approved Whether the `operator` is approved or not.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Emitted when a delegate is approved or an approval is revoked.
    ///
    /// @param owner The address of the owner of the name.
    /// @param node The namehash of the name.
    /// @param delegate The address of the delegate for the specified `node`.
    /// @param approved Whether the `delegate` is approved for the specified `node`.
    event Approved(address owner, bytes32 indexed node, address indexed delegate, bool indexed approved);

    /// @notice Emitted when a controller address approval status is changed by the `owner`.
    ///
    /// @param controller The address of the `controller`.
    /// @param approved The new approval state for the `controller` address.
    event ControllerApprovalChanged(address indexed controller, bool approved);

    /// @notice Emitted when the owner of this contract updates the Reverse Registrar address.
    ///
    /// @param newReverseRegistrar The address of the new ReverseRegistrar contract.
    event ReverseRegistrarUpdated(address indexed newReverseRegistrar);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        IMPLEMENTATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() {
        _disableInitializers();
    }

    /// @notice L2 Resolver constructor used to establish the necessary contract configuration.
    ///
    /// @param registry_ The Registry contract.
    /// @param registrarController_ The address of the RegistrarController contract.
    /// @param reverseRegistrar_ The address of the ReverseRegistrar contract.
    /// @param owner_  The permissioned address initialized as the `owner` in the `Ownable` context.
    function initialize(ENS registry_, address registrarController_, address reverseRegistrar_, address owner_)
        public
        initializer
    {
        ResolverStorage storage $ = _getResolverStorage();
        $.registry = registry_;
        $.approvedControllers[registrarController_] = true;
        $.reverseRegistrar = reverseRegistrar_;
        __Ownable_init(owner_);
        IReverseRegistrar(reverseRegistrar_).claim(owner_);
    }

    /// @notice Allows the owner to change the approval status of an address as a controller.
    ///
    /// @param controller The address of the controller.
    /// @param approved Whether the controller has permissions to modify reverse records.
    function setControllerApproval(address controller, bool approved) external onlyOwner {
        if (controller == address(0)) revert NoZeroAddress();
        _getResolverStorage().approvedControllers[controller] = approved;
        emit ControllerApprovalChanged(controller, approved);
    }

    /// @notice Fetch whether an address is an approved controller.
    ///
    /// @param controller The address of the controller to query.
    ///
    /// @return `true` if `controller` is an approved controller, else `false`.
    function getControllerApproval(address controller) external view returns (bool) {
        return _getResolverStorage().approvedControllers[controller];
    }

    /// @notice Allows the `owner` to set the reverse registrar contract address.
    ///
    /// @dev Emits `ReverseRegistrarUpdated` after setting the `reverseRegistrar` address.
    ///
    /// @param reverseRegistrar_ The address of the new ReverseRegistrar contract.
    function setReverseRegistrar(address reverseRegistrar_) external onlyOwner {
        if (reverseRegistrar_ == address(0)) revert NoZeroAddress();
        _getResolverStorage().reverseRegistrar = reverseRegistrar_;
        emit ReverseRegistrarUpdated(reverseRegistrar_);
    }

    /// @notice Returns the address of the reverse registrar contract.
    function reverseRegistrar() external view returns (address) {
        return _getResolverStorage().reverseRegistrar;
    }

    /// @dev See {IERC1155-setApprovalForAll}.
    function setApprovalForAll(address operator, bool approved) external {
        if (msg.sender == operator) revert CantSetSelfAsOperator();

        _getResolverStorage()._operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Modify the permissions for a specified `delegate` for the specified `node`.
    ///
    /// @dev This method only sets the approval status for msg.sender's nodes. This is performed without checking
    ///     the ownership of the specified `node`.
    ///
    /// @param node The namehash `node` whose permissions are being updated.
    /// @param delegate The address of the `delegate`.
    /// @param approved Whether the `delegate` has approval to modify records for `msg.sender`'s `node`.
    function approve(bytes32 node, address delegate, bool approved) external {
        if (msg.sender == delegate) revert CantSetSelfAsDelegate();

        _getResolverStorage()._tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /// @dev See {IERC1155-isApprovedForAll}.
    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _getResolverStorage()._operatorApprovals[account][operator];
    }

    /// @notice Check to see if the `delegate` has been approved by the `owner` for the `node`.
    ///
    /// @param owner The address of the name owner.
    /// @param node The namehash `node` whose permissions are being checked.
    /// @param delegate The address of the `delegate` whose permissions are being checked.
    ///
    /// @return `true` if `delegate` is approved to modify `msg.sender`'s `node`, else `false`.
    function isApprovedFor(address owner, bytes32 node, address delegate) public view returns (bool) {
        return _getResolverStorage()._tokenApprovals[owner][node][delegate];
    }

    /// @notice Check to see whether `msg.sender` is authorized to modify records for the specified `node`.
    ///
    /// @dev Override for `ResolverBase:isAuthorized()`. Used in the context of each inherited resolver "profile".
    ///     Validates that `msg.sender` is one of:
    ///     1. The stored registrarController (for setting records upon registration)
    ///     2  The stored reverseRegistrar (for setting reverse records)
    ///     3. The owner of the node in the Registry
    ///     4. An approved operator for owner
    ///     5. An approved delegate for owner of the specified `node`
    ///
    /// @param node The namehashed `node` being authorized.
    ///
    /// @return `true` if `msg.sender` is authorized to modify records for the specified `node`, else `false`.
    function isAuthorized(bytes32 node) internal view override returns (bool) {
        ResolverStorage storage $ = _getResolverStorage();
        if ($.approvedControllers[msg.sender] || msg.sender == $.reverseRegistrar) {
            return true;
        }
        address owner = $.registry.owner(node);
        return owner == msg.sender || isApprovedForAll(owner, msg.sender) || isApprovedFor(owner, node, msg.sender);
    }

    /// @notice ERC165 compliant signal for interface support.
    ///
    /// @dev Checks interface support for each inherited resolver profile
    ///     https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
    ///
    /// @param interfaceID the ERC165 iface id being checked for compliance.
    ///
    /// @return bool Whether this contract supports the provided interfaceID.
    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return (interfaceID == type(IExtendedResolver).interfaceId || super.supportsInterface(interfaceID));
    }

    /// @notice EIP-7201 storage pointer fetch helper.
    function _getResolverStorage() internal pure returns (ResolverStorage storage $) {
        assembly {
            $.slot := RESOLVER_STORAGE_LOCATION
        }
    }
}
