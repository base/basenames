// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMulticallable} from "ens-contracts/resolvers/IMulticallable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";

import {BASE_ETH_NODE, GRACE_PERIOD} from "src/util/Constants.sol";
import {IBaseRegistrar} from "./interface/IBaseRegistrar.sol";
import {IDiscountValidator} from "./interface/IDiscountValidator.sol";
import {IL2ReverseRegistrar} from "./interface/IL2ReverseRegistrar.sol";
import {IPriceOracle} from "./interface/IPriceOracle.sol";
import {IReverseRegistrar} from "./interface/IReverseRegistrar.sol";
import {IRegistrarController} from "./interface/IRegistrarController.sol";

/// @title Upgradeable Registrar Controller Version 1
///
/// @notice A permissioned controller for managing registering and renewing names against the `BaseRegistrar` contract.
///         This contract enables a `discountedRegister` flow which is validated by calling external implementations
///         of the `IDiscountValidator` interface. Pricing, denominated in wei, is determined by calling out to a
///         contract that implements `IPriceOracle`.
///
///         Inspired by the ENS ETHRegistrarController:
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/ETHRegistrarController.sol
///
/// @author Coinbase (https://github.com/base/basenames)
contract UpgradeableRegistrarController is Ownable2StepUpgradeable {
    using StringUtils for *;
    using SafeERC20 for IERC20;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /// @notice The details of a modern registration request, compatible with ENSIP-19.
    struct RegisterRequest {
        /// @dev The name being registered.
        string name;
        /// @dev The address of the owner for the name.
        address owner;
        /// @dev The duration of the registration in seconds.
        uint256 duration;
        /// @dev The address of the resolver to set for this name.
        address resolver;
        /// @dev Multicallable data bytes for setting records in the associated resolver upon registration.
        bytes[] data;
        /// @dev Bool to decide whether to set this name as the "primary" name for the `owner`.
        bool reverseRecord;
        /// @dev Array of coinTypes for reverse record setting.
        uint256[] coinTypes;
        /// @dev Signature expiry.
        uint256 signatureExpiry;
        /// @dev Signature payload.
        bytes signature;
    }

    /// @notice The details of a discount tier.
    struct DiscountDetails {
        /// @dev Bool which declares whether the discount is active or not.
        bool active;
        /// @dev The address of the associated validator. It must implement `IDiscountValidator`.
        address discountValidator;
        /// @dev The unique key that identifies this discount.
        bytes32 key;
        /// @dev The discount value denominated in wei.
        uint256 discount;
    }

    /// @notice Storage struct for UpgradeableRegistrarController (URC).
    /// @custom:storage-location erc7201:upgradeableregistrarcontroller.storage
    struct URCStorage {
        /// @notice The implementation of the `BaseRegistrar`.
        IBaseRegistrar base;
        /// @notice The implementation of the pricing oracle.
        IPriceOracle prices;
        /// @notice The implementation of the Reverse Registrar contract.
        IReverseRegistrar reverseRegistrar;
        /// @notice The address of the L2 Reverse Registrar.
        address l2ReverseRegistrar;
        /// @notice An enumerable set for tracking which discounts are currently active.
        EnumerableSetLib.Bytes32Set activeDiscounts;
        /// @notice The node for which this name enables registration. It must match the `rootNode` of `base`.
        bytes32 rootNode;
        /// @notice The name for which this registration adds subdomains for, i.e. ".base.eth".
        string rootName;
        /// @notice The address that will receive ETH funds upon `withdraw()` being called.
        address paymentReceiver;
        /// @notice The address of the legacy registrar controller.
        address legacyRegistrarController;
        /// @notice The address of the legacy L2 Resolver.
        address legacyL2Resolver;
        /// @notice Each discount is stored against a unique 32-byte identifier, i.e. keccak256("test.discount.validator").
        mapping(bytes32 key => DiscountDetails details) discounts;
        /// @notice Storage for which addresses have already registered with a discount.
        mapping(address registrant => bool hasRegisteredWithDiscount) discountedRegistrants;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The minimum registration duration, specified in seconds.
    uint256 public constant MIN_REGISTRATION_DURATION = 365 days;

    /// @notice The minimum name length.
    uint256 public constant MIN_NAME_LENGTH = 3;

    /// @notice The EIP-7201 storage location, determined by:
    ///     keccak256(abi.encode(uint256(keccak256("upgradeable.registrar.controller.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant _UPGRADEABLE_REGISTRAR_CONTROLLER_STORAGE_LOCATION =
        0xf52df153eda7a96204b686efee7d70251f4cef9d04988d95cc73d1a93f655200;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERRORS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Thrown when the sender has already registered with a discount.
    ///
    /// @param sender The address of the sender.
    error AlreadyRegisteredWithDiscount(address sender);

    /// @notice Thrown when a name is not valid.
    ///
    /// @param name The name that is not valid.
    error NameNotValid(string name);

    /// @notice Thrown when a name's duration is not longer than `MIN_REGISTRATION_DURATION`.
    ///
    /// @param duration The duration that was too short.
    error DurationTooShort(uint256 duration);

    /// @notice Thrown when Multicallable resolver data was specified but no resolver address was provided.
    error ResolverRequiredWhenDataSupplied();

    /// @notice Thrown when a `discountedRegister` claim tries to access an inactive discount.
    ///
    /// @param key The discount key that is inactive.
    error InactiveDiscount(bytes32 key);

    /// @notice Thrown when the payment received is less than the price.
    error InsufficientValue();

    /// @notice Thrown when the specified discount's validator does not accept the discount for the sender.
    ///
    /// @param key The discount being accessed.
    /// @param data The associated `validationData`.
    error InvalidDiscount(bytes32 key, bytes data);

    /// @notice Thrown when the discount amount is 0.
    ///
    /// @param key The discount being set.
    error InvalidDiscountAmount(bytes32 key);

    /// @notice Thrown when the payment receiver is being set to address(0).
    error InvalidPaymentReceiver();

    /// @notice Thrown when the discount validator is being set to address(0).
    ///
    /// @param key The discount being set.
    /// @param validator The address of the validator being set.
    error InvalidValidator(bytes32 key, address validator);

    /// @notice Thrown when the modular contract address is set to address(0).
    error ZeroAddress();

    /// @notice Thrown when a refund transfer is unsuccessful.
    error TransferFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a discount is set or updated.
    ///
    /// @param discountKey The unique identifier key for the discount.
    /// @param details The DiscountDetails struct stored for this key.
    event DiscountUpdated(bytes32 indexed discountKey, DiscountDetails details);

    /// @notice Emitted when an ETH payment was processed successfully.
    ///
    /// @param payee Address that sent the ETH.
    /// @param price Value that was paid.
    event ETHPaymentProcessed(address indexed payee, uint256 price);

    /// @notice Emitted when a name was registered.
    ///
    /// @param name The name that was registered.
    /// @param label The hashed label of the name.
    /// @param owner The owner of the name that was registered.
    /// @param expires The date when the registration expires.
    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 expires);

    /// @notice Emitted when a name is renewed.
    ///
    /// @param name The name that was renewed.
    /// @param label The hashed label of the name.
    /// @param expires The date that the renewed name expires.
    event NameRenewed(string name, bytes32 indexed label, uint256 expires);

    /// @notice Emitted when a name is registered with a discount.
    ///
    /// @param registrant The address of the registrant.
    /// @param discountKey The discount key that was used to register.
    event DiscountApplied(address indexed registrant, bytes32 indexed discountKey);

    /// @notice Emitted when the payment receiver is updated.
    ///
    /// @param newPaymentReceiver The address of the new payment receiver.
    event PaymentReceiverUpdated(address newPaymentReceiver);

    /// @notice Emitted when the price oracle is updated.
    ///
    /// @param newPrices The address of the new price oracle.
    event PriceOracleUpdated(address newPrices);

    /// @notice Emitted when the reverse registrar is updated.
    ///
    /// @param newReverseRegistrar The address of the new reverse registrar.
    event ReverseRegistrarUpdated(address newReverseRegistrar);

    /// @notice Emitted when the  L2ReverseRegistrar address is updated.
    ///
    /// @param newL2ReverseRegistrar The address of the new l2ReverseRegistrar.
    event L2ReverseRegistrarUpdated(address newL2ReverseRegistrar);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MODIFIERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Decorator for validating registration requests.
    ///
    /// @dev Validates that:
    ///     1. There is a `resolver` specified` when `data` is set
    ///     2. That the name is `valid()`
    ///     3. That the registration `duration` is sufficiently long
    ///
    /// @param request The RegisterRequest that is being validated.
    modifier validRegistration(RegisterRequest calldata request) {
        if (request.data.length > 0 && request.resolver == address(0)) {
            revert ResolverRequiredWhenDataSupplied();
        }
        if (!valid(request.name)) {
            revert NameNotValid(request.name);
        }
        if (request.duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(request.duration);
        }
        _;
    }

    /// @notice Decorator for validating discounted registrations.
    ///
    /// @dev Validates that:
    ///     1. That the registrant has not already registered with a discount.
    ///     2. That the discount is `active`.
    ///     3. That the associated `discountValidator` returns true when `isValidDiscountRegistration` is called.
    ///
    /// @param discountKey The uuid of the discount.
    /// @param validationData The associated validation data for this discount registration.
    modifier validDiscount(bytes32 discountKey, bytes calldata validationData) {
        URCStorage storage $ = _getURCStorage();
        if (
            $.discountedRegistrants[msg.sender]
                || IRegistrarController($.legacyRegistrarController).discountedRegistrants(msg.sender)
        ) revert AlreadyRegisteredWithDiscount(msg.sender);
        DiscountDetails memory details = $.discounts[discountKey];

        if (!details.active) revert InactiveDiscount(discountKey);

        IDiscountValidator validator = IDiscountValidator(details.discountValidator);
        if (!validator.isValidDiscountRegistration(msg.sender, validationData)) {
            revert InvalidDiscount(discountKey, validationData);
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        IMPLEMENTATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Registrar Controller initialization.
    ///
    /// @dev Assigns ownership of this contract's reverse record to the `owner_`.
    ///
    /// @param base_ The base registrar contract.
    /// @param prices_ The pricing oracle contract.
    /// @param reverseRegistrar_ The reverse registrar contract.
    /// @param owner_ The permissioned address initialized as the `owner` in the `Ownable` context.
    /// @param rootNode_ The node for which this registrar manages registrations.
    /// @param rootName_ The name of the root node which this registrar manages.
    /// @param paymentReceiver_ The address of the fee collector.
    /// @param legacyRegistrarController_ The address of the RegistrarController contract.
    /// @param legacyL2Resolver_ The address of the legacy resolver for storing reverse records.
    /// @param l2ReverseRegistrar_ The address of the ENS-deployed L2 Reverse Registrar.
    function initialize(
        IBaseRegistrar base_,
        IPriceOracle prices_,
        IReverseRegistrar reverseRegistrar_,
        address owner_,
        bytes32 rootNode_,
        string memory rootName_,
        address paymentReceiver_,
        address legacyRegistrarController_,
        address legacyL2Resolver_,
        address l2ReverseRegistrar_
    ) public initializer onlyInitializing {
        __Ownable_init(owner_);

        URCStorage storage $ = _getURCStorage();
        $.base = base_;
        $.prices = prices_;
        $.reverseRegistrar = reverseRegistrar_;
        $.rootNode = rootNode_;
        $.rootName = rootName_;
        $.paymentReceiver = paymentReceiver_;
        $.legacyRegistrarController = legacyRegistrarController_;
        $.legacyL2Resolver = legacyL2Resolver_;
        $.l2ReverseRegistrar = l2ReverseRegistrar_;
    }

    /// @notice Allows the `owner` to set discount details for a specified `key`.
    ///
    /// @dev Validates that:
    ///     1. The discount `amount` is nonzero
    ///     2. The uuid `key` matches the one set in the details
    ///     3. That the address of the `discountValidator` is not the zero address
    ///     Updates the `ActiveDiscounts` enumerable set then emits `DiscountUpdated` event.
    ///
    /// @param details The DiscountDetails for this discount key.
    function setDiscountDetails(DiscountDetails memory details) external onlyOwner {
        if (details.discount == 0) revert InvalidDiscountAmount(details.key);
        if (details.discountValidator == address(0)) revert InvalidValidator(details.key, details.discountValidator);
        _getURCStorage().discounts[details.key] = details;
        _updateActiveDiscounts(details.key, details.active);
        emit DiscountUpdated(details.key, details);
    }

    /// @notice Allows the `owner` to set the pricing oracle contract.
    ///
    /// @dev Emits `PriceOracleUpdated` after setting the `prices` contract.
    ///
    /// @param prices_ The new pricing oracle.
    function setPriceOracle(IPriceOracle prices_) external onlyOwner {
        if (address(prices_) == address(0)) revert ZeroAddress();
        _getURCStorage().prices = prices_;
        emit PriceOracleUpdated(address(prices_));
    }

    /// @notice Allows the `owner` to set the reverse registrar contract.
    ///
    /// @dev Emits `ReverseRegistrarUpdated` after setting the `reverseRegistrar` contract.
    ///
    /// @param reverse_ The new reverse registrar contract.
    function setReverseRegistrar(IReverseRegistrar reverse_) external onlyOwner {
        if (address(reverse_) == address(0)) revert ZeroAddress();
        _getURCStorage().reverseRegistrar = reverse_;
        emit ReverseRegistrarUpdated(address(reverse_));
    }

    /// @notice Allows the `owner` to set the address of the L2ReverseRegistrar.
    ///
    /// @dev Emits `L2ReverseRegistrarUpdated` after setting the `L2ReverseRegistrar` contract address.
    ///
    /// @param l2ReverseRegistrar_ The new reverse registrar contract.
    function setL2ReverseRegistrar(address l2ReverseRegistrar_) external onlyOwner {
        if (l2ReverseRegistrar_ == address(0)) revert ZeroAddress();
        _getURCStorage().l2ReverseRegistrar = l2ReverseRegistrar_;
        emit L2ReverseRegistrarUpdated(l2ReverseRegistrar_);
    }

    /// @notice Allows the `owner` to set the payment receiver address.
    ///
    /// @dev Emits `PaymentReceiverUpdated` after setting the `paymentReceiver` address.
    ///
    /// @param paymentReceiver_ The new payment receiver address.
    function setPaymentReceiver(address paymentReceiver_) external onlyOwner {
        if (paymentReceiver_ == address(0)) revert InvalidPaymentReceiver();
        _getURCStorage().paymentReceiver = paymentReceiver_;
        emit PaymentReceiverUpdated(paymentReceiver_);
    }

    /// @notice Checks whether any of the provided addresses have registered with a discount.
    ///
    /// @param addresses The array of addresses to check for discount registration.
    ///
    /// @return `true` if any of the addresses have already registered with a discount, else `false`.
    function hasRegisteredWithDiscount(address[] memory addresses) external view returns (bool) {
        URCStorage storage $ = _getURCStorage();
        if (IRegistrarController($.legacyRegistrarController).hasRegisteredWithDiscount(addresses)) return true;
        for (uint256 i; i < addresses.length; i++) {
            if ($.discountedRegistrants[addresses[i]]) {
                return true;
            }
        }
        return false;
    }

    /// @notice Fetches a specific discount from storage.
    ///
    /// @param discountKey The uuid of the discount to fetch.
    ///
    /// @return DiscountDetails associated with the provided `discountKey`.
    function discounts(bytes32 discountKey) external view returns (DiscountDetails memory) {
        return _getURCStorage().discounts[discountKey];
    }

    /// @notice Fetches the payment receiver from storage.abi
    ///
    /// @return The address of the payment receiver.
    function paymentReceiver() external view returns (address) {
        return _getURCStorage().paymentReceiver;
    }

    /// @notice Fetches the price oracle from storage.
    ///
    /// @return The stored prices oracle.
    function prices() external view returns (IPriceOracle) {
        return _getURCStorage().prices;
    }

    /// @notice Fetches the Reverse Registrar from storage.
    ///
    /// @return The stored Reverse Registrar.
    function reverseRegistrar() external view returns (IReverseRegistrar) {
        return _getURCStorage().reverseRegistrar;
    }

    /// @notice Check which discounts are currently set to `active`.
    ///
    /// @return An array of `DiscountDetails` that are all currently marked as `active`.
    function getActiveDiscounts() external view returns (DiscountDetails[] memory) {
        URCStorage storage $ = _getURCStorage();
        bytes32[] memory activeDiscountKeys = $.activeDiscounts.values();
        DiscountDetails[] memory activeDiscountDetails = new DiscountDetails[](activeDiscountKeys.length);
        for (uint256 i; i < activeDiscountKeys.length; i++) {
            activeDiscountDetails[i] = $.discounts[activeDiscountKeys[i]];
        }
        return activeDiscountDetails;
    }

    /// @notice Checks whether the provided `name` is long enough.
    ///
    /// @param name The name to check the length of.
    ///
    /// @return `true` if the name is equal to or longer than MIN_NAME_LENGTH, else `false`.
    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= MIN_NAME_LENGTH;
    }

    /// @notice Checks whether the provided `name` is available.
    ///
    /// @param name The name to check the availability of.
    ///
    /// @return `true` if the name is `valid` and available on the `base` registrar, else `false`.
    function available(string memory name) external view returns (bool) {
        return valid(name) && _getURCStorage().base.isAvailable(uint256(_getLabelFromName(name)));
    }

    /// @notice Checks the rent price for a provided `name` and `duration`.
    ///
    /// @param name The name to check the rent price of.
    /// @param duration The time that the name would be rented.
    ///
    /// @return price The `Price` tuple containing the base and premium prices respectively, denominated in wei.
    function rentPrice(string memory name, uint256 duration) public view returns (IPriceOracle.Price memory price) {
        price = _getURCStorage().prices.price({
            name: name,
            expires: _getExpiry(uint256(_getLabelFromName(name))),
            duration: duration
        });
    }

    /// @notice Checks the register price for a provided `name` and `duration`.
    ///
    /// @param name The name to check the register price of.
    /// @param duration The time that the name would be registered.
    ///
    /// @return The all-in price for the name registration, denominated in wei.
    function registerPrice(string memory name, uint256 duration) public view returns (uint256) {
        IPriceOracle.Price memory price = rentPrice(name, duration);
        return price.base + price.premium;
    }

    /// @notice Checks the discounted register price for a provided `name`, `duration` and `discountKey`.
    ///
    /// @dev The associated `DiscountDetails.discount` is subtracted from the price returned by calling `registerPrice()`.
    ///
    /// @param name The name to check the discounted register price of.
    /// @param duration The time that the name would be registered.
    /// @param discountKey The uuid of the discount to apply.
    ///
    /// @return price The all-in price for the discounted name registration, denominated in wei. Returns 0
    ///         if the price of the discount exceeds the nominal registration fee.
    function discountedRegisterPrice(string memory name, uint256 duration, bytes32 discountKey)
        public
        view
        returns (uint256 price)
    {
        uint256 discount = _getURCStorage().discounts[discountKey].discount;
        price = registerPrice(name, duration);
        price = (price > discount) ? price - discount : 0;
    }

    /// @notice Enables a caller to register a name using the legacy registration data.
    ///
    /// @dev Validates the registration details via the `validRegistration` modifier.
    ///     This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function register(RegisterRequest calldata request) external payable validRegistration(request) {
        uint256 price = registerPrice(request.name, request.duration);

        _validatePayment(price);

        _register(request);

        _refundExcessEth(price);
    }

    /// @notice Enables a caller to register a name and apply a discount.
    ///
    /// @dev In addition to the validation performed in a `register` request, this method additionally validates
    ///     that msg.sender is eligible for the specified `discountKey` given the provided `validationData`.
    ///     The specific encoding of `validationData` is specified in the implementation of the `discountValidator`
    ///     that is being called.
    ///     Emits `RegisteredWithDiscount` upon successful registration.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    /// @param discountKey The uuid of the discount being accessed.
    /// @param validationData Data necessary to perform the associated discount validation.
    function discountedRegister(RegisterRequest calldata request, bytes32 discountKey, bytes calldata validationData)
        external
        payable
        validDiscount(discountKey, validationData)
        validRegistration(request)
    {
        URCStorage storage $ = _getURCStorage();

        uint256 price = discountedRegisterPrice(request.name, request.duration, discountKey);

        _validatePayment(price);

        $.discountedRegistrants[msg.sender] = true;
        _register(request);

        _refundExcessEth(price);

        emit DiscountApplied(msg.sender, discountKey);
    }

    /// @notice Allows a caller to renew a name for a specified duration.
    ///
    /// @dev This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///     The price for renewal never incorporates pricing `premium`. This is because we only expect
    ///     renewal on names that are not expired or are in the grace period. Use the `base` price returned
    ///     by the `rentPrice` tuple to determine the price for calling this method.
    ///
    /// @param name The name that is being renewed.
    /// @param duration The duration to extend the expiry, in seconds.
    function renew(string calldata name, uint256 duration) external payable {
        URCStorage storage $ = _getURCStorage();
        bytes32 label = _getLabelFromName(name);
        uint256 tokenId = uint256(label);
        IPriceOracle.Price memory price = rentPrice(name, duration);

        _validatePayment(price.base);

        uint256 expires = $.base.renew(tokenId, duration);

        _refundExcessEth(price.base);

        emit NameRenewed(name, label, expires);
    }

    /// @notice Externally callable reverse record setter.
    ///
    /// @dev For use by clients wishing to maintain backwards compatibility while migrating to full
    ///     ENSIP-19 compliance.
    ///
    /// @param name The name that will be set as the primary for msg.sender.
    /// @param signatureExpiry The signature expiry timestamp.
    /// @param coinTypes The array of coinTypes for replayable reverse record setting.
    /// @param signature The signature bytes.
    function setReverseRecord(
        string calldata name,
        uint256 signatureExpiry,
        uint256[] calldata coinTypes,
        bytes calldata signature
    ) external {
        _setReverseRecord(name, signatureExpiry, coinTypes, signature);
    }

    /// @notice Internal helper for validating ETH payments
    ///
    /// @dev Emits `ETHPaymentProcessed` after validating the payment.
    ///
    /// @param price The required value.
    function _validatePayment(uint256 price) internal {
        if (msg.value < price) revert InsufficientValue();
        emit ETHPaymentProcessed(msg.sender, price);
    }

    /// @notice Shared registration logic for both `register()` and `discountedRegister()`.
    ///
    /// @dev Will set records in the specified resolver if the resolver address is non zero and there is `data` in the `request`.
    ///     Will set the reverse record's owner as msg.sender if `reverseRecord` is `true`.
    ///     Emits `NameRegistered` upon successful registration.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function _register(RegisterRequest calldata request) internal {
        bytes32 label = _getLabelFromName(request.name);
        uint256 expires = _getURCStorage().base.registerWithRecord({
            id: uint256(label),
            owner: request.owner,
            duration: request.duration,
            resolver: request.resolver,
            ttl: 0
        });

        if (request.data.length > 0) {
            _setRecords(request.resolver, label, request.data);
        }

        if (request.reverseRecord) {
            _setReverseRecord(request.name, request.signatureExpiry, request.coinTypes, request.signature);
        }

        emit NameRegistered(request.name, label, request.owner, expires);
    }

    /// @notice Refunds any remaining `msg.value` after processing a registration or renewal given `price`.
    ///
    /// @dev It is necessary to allow "overpayment" because of premium price decay.  We don't want transactions to fail
    ///     unnecessarily if the premium decreases between tx submission and inclusion.
    ///
    /// @param price The total value to be retained, denominated in wei.
    function _refundExcessEth(uint256 price) internal {
        if (msg.value > price) {
            (bool sent,) = payable(msg.sender).call{value: (msg.value - price)}("");
            if (!sent) revert TransferFailed();
        }
    }

    /// @notice Uses Multicallable to iteratively set records on a specified resolver.
    ///
    /// @dev `multicallWithNodeCheck` ensures that each record being set is for the specified `label`.
    ///
    /// @param resolverAddress The address of the resolver to set records on.
    /// @param label The keccak256 hash for the specified name.
    /// @param data  The abi encoded calldata records that will be used in the multicallable resolver.
    function _setRecords(address resolverAddress, bytes32 label, bytes[] calldata data) internal {
        bytes32 nodehash = keccak256(abi.encodePacked(_getURCStorage().rootNode, label));
        IMulticallable(resolverAddress).multicallWithNodeCheck(nodehash, data);
    }

    /// @notice Internal helper for setting reverse records.
    ///
    /// @dev First sets the reverse record according to the legacy path via ReverseRegistrar. Then
    ///     if the data is populated, sets the reverse record according to the ENSIP-19 compliant path
    ///     by calling ENS's L2ReverseRegistrar contract.
    ///
    /// @param name The name that will be set as the primary for msg.sender.
    /// @param signatureExpiry The signature expiry timestamp.
    /// @param coinTypes The array of cointypes for replayable reverse record setting.
    /// @param signature The signature bytes.
    function _setReverseRecord(
        string calldata name,
        uint256 signatureExpiry,
        uint256[] calldata coinTypes,
        bytes calldata signature
    ) internal {
        URCStorage storage $ = _getURCStorage();
        string memory fullName = string.concat(name, $.rootName);
        _setLegacyReverseRecord(fullName, msg.sender);
        if (signatureExpiry != 0 && coinTypes.length > 0 && signature.length > 0) {
            IL2ReverseRegistrar($.l2ReverseRegistrar).setNameForAddrWithSignature(
                msg.sender, signatureExpiry, fullName, coinTypes, signature
            );
        }
    }

    /// @notice Sets the reverse record to `owner` for a specified `name` on the specified `resolver`.
    ///
    /// @param name The specified name.
    /// @param owner  The owner of the reverse record.
    function _setLegacyReverseRecord(string memory name, address owner) internal {
        URCStorage storage $ = _getURCStorage();
        // Use legacyL2Resolver because all legacy reverse records are stored there.
        $.reverseRegistrar.setNameForAddr(owner, owner, $.legacyL2Resolver, name);
    }

    /// @notice Helper method for updating the `activeDiscounts` enumerable set.
    ///
    /// @dev Adds the discount `key` to the set if it is active or removes if it is inactive.
    ///
    /// @param key The uuid of the discount.
    /// @param active Whether the specified discount is active or not.
    function _updateActiveDiscounts(bytes32 key, bool active) internal {
        URCStorage storage $ = _getURCStorage();
        active ? $.activeDiscounts.add(key) : $.activeDiscounts.remove(key);
    }

    /// @notice Getter for fetching token expiry.
    ///
    /// @dev If the token returns a `0` expiry time, it hasn't been registered before.
    ///
    /// @param tokenId The ID of the token to check for expiry.
    ///
    /// @return expires Returns the expiry + GRACE_PERIOD for previously registered names, else 0.
    function _getExpiry(uint256 tokenId) internal view returns (uint256 expires) {
        expires = _getURCStorage().base.nameExpires(tokenId);
        return expires == 0 ? 0 : expires + GRACE_PERIOD;
    }

    /// @notice Helper for calculating the label of a given name.
    ///
    /// @param name The singular name, i.e. `jesse`.
    ///
    /// @return label The keccak256 hash of the provided `name`.
    function _getLabelFromName(string memory name) internal pure returns (bytes32 label) {
        label = keccak256(bytes(name));
    }

    /// @notice Allows anyone to withdraw the eth accumulated on this contract back to the `paymentReceiver`.
    function withdrawETH() public {
        (bool sent,) = payable(_getURCStorage().paymentReceiver).call{value: (address(this).balance)}("");
        if (!sent) revert TransferFailed();
    }

    function _getURCStorage() private pure returns (URCStorage storage $) {
        assembly {
            $.slot := _UPGRADEABLE_REGISTRAR_CONTROLLER_STORAGE_LOCATION
        }
    }
}
