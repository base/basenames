// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";

import {BASE_ETH_NODE, GRACE_PERIOD} from "src/util/Constants.sol";
import {BaseRegistrar} from "./BaseRegistrar.sol";
import {DiscountValidator} from "./discounts/DiscountValidator.sol";
import {IPriceOracle} from "./interface/IPriceOracle.sol";
import {L2Resolver} from "./L2Resolver.sol";
import {IReverseRegistrar} from "./interface/IReverseRegistrar.sol";

/// @title Registrar Controller
///
/// @notice A permissioned controller for managing registering and renewing names against the `base` registrar.
///         This contract enables a `discountedRegister` flow which is validated by calling external implementations
///         of the `IDiscountValidator` interface. Pricing, denominated in wei, is determined by calling out to a
///         contract that implements `IPriceOracle`.
///
///         Inspired by the ENS ETHRegistrarController:
///         https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/ETHRegistrarController.sol
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract RegistrarController is Ownable {
    using StringUtils for *;
    using SafeERC20 for IERC20;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /// @notice The details of a registration request.
    struct RegisterRequest {
        /// @dev The name being registered.
        string name;
        /// @dev The address of the owner for the name.
        address owner;
        /// @dev The duration of the registration in seconds.
        uint256 duration;
        /// @dev The address of the resolver to set for this name.
        address resolver;
        /// @dev Multicallable data bytes for setting records in the associated resolver upon reigstration.
        bytes[] data;
        /// @dev Bool to decide whether to set this name as the "primary" name for the `owner`.
        bool reverseRecord;
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The implementation of the `BaseRegistrar`.
    BaseRegistrar immutable base;

    /// @notice The implementation of the pricing oracle.
    IPriceOracle public prices;

    /// @notice The implementation of the Reverse Registrar contract.
    IReverseRegistrar public reverseRegistrar;

    /// @notice An enumerable set for tracking which discounts are currently active.
    EnumerableSetLib.Bytes32Set internal activeDiscounts;

    /// @notice The node for which this name enables registration. It must match the `rootNode` of `base`.
    bytes32 public immutable rootNode;

    /// @notice The name for which this registration adds subdomains for, i.e. ".base.eth".
    string public rootName;

    /// @notice The address that will receive ETH funds upon `withdraw()` being called.
    address public paymentReceiver;

    /// @notice The timestamp of "go-live". Used for setting at-launch pricing premium.
    uint256 public launchTime;

    /// @notice Each discount is stored against a unique 32-byte identifier, i.e. keccak256("test.discount.validator").
    mapping(bytes32 key => DiscountDetails details) public discounts;

    /// @notice Storage for which addresses have already registered with a discount.
    mapping(address registrant => bool hasRegisteredWithDiscount) public discountedRegistrants;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The minimum registration duration, specified in seconds.
    uint256 public constant MIN_REGISTRATION_DURATION = 365 days;

    /// @notice The minimum name length.
    uint256 public constant MIN_NAME_LENGTH = 3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERRORS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Thrown when the sender has already registered with a discount.
    ///
    /// @param sender The address of the sender.
    error AlreadyRegisteredWithDiscount(address sender);

    /// @notice Thrown when a name is not available.
    ///
    /// @param name The name that is not available.
    error NameNotAvailable(string name);

    /// @notice Thrown when a name's duration is not longer than `MIN_REGISTRATION_DURATION`.
    ///
    /// @param duration The duration that was too short.
    error DurationTooShort(uint256 duration);

    /// @notice Thrown when Multicallable resolver data was specified but not resolver address was provided.
    error ResolverRequiredWhenDataSupplied();

    /// @notice Thrown when a `discountedRegister` claim tries to access an inactive discount.
    ///
    /// @param key The discount key that is inactive.
    error InactiveDiscount(bytes32 key);

    /// @notice Thrown when the payment received is less than the price.
    error InsufficientValue();

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
    /// @param expires The date that the registration expires.
    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 expires);

    /// @notice Emitted when a name is renewed.
    ///
    /// @param name The name that was renewed.
    /// @param label The hashed label of the name.
    /// @param expires The date that the renewed name expires.
    event NameRenewed(string name, bytes32 indexed label, uint256 expires);

    /// @notice Emitted when the payment receiver is updated.
    ///
    /// @param newPaymentReceiver The address of the new payment receiver.
    event PaymentReceiverUpdated(address newPaymentReceiver);

    /// @notice Emitted when the price oracle is updated.
    ///
    /// @param newPrices The address of the new price oracle.
    event PriceOracleUpdated(address newPrices);

    /// @notice Emitted when a name is registered with a discount.
    ///
    /// @param registrant The address of the registrant.
    /// @param discountKey The discount key that was used to register.
    event DiscountApplied(address indexed registrant, bytes32 indexed discountKey);

    /// @notice Emitted when the reverse registrar is updated.
    ///
    /// @param newReverseRegistrar The address of the new reverse registrar.
    event ReverseRegistrarUpdated(address newReverseRegistrar);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MODIFIERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Decorator for validating registration requests.
    ///
    /// @dev Validates that:
    ///     1. There is a `resolver` specified` when `data` is set
    ///     2. That the name is `available()`
    ///     3. That the registration `duration` is sufficiently long
    ///
    /// @param request The RegisterRequest that is being validated.
    modifier validRegistration(RegisterRequest calldata request) {
        if (request.data.length > 0 && request.resolver == address(0)) {
            revert ResolverRequiredWhenDataSupplied();
        }
        if (!available(request.name)) {
            revert NameNotAvailable(request.name);
        }
        if (request.duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(request.duration);
        }
        _;
    }

    /// @notice Decorator for validating a user for discounted registration.
    ///
    /// @dev Validates that that the registrant has not already registered with a discount
    modifier discountAvailable() {
        if (discountedRegistrants[msg.sender]) revert AlreadyRegisteredWithDiscount(msg.sender);
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        IMPLEMENTATION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Registrar Controller construction sets all of the requisite external contracts.
    ///
    /// @dev Assigns ownership of this contract's reverse record to the `owner_`.
    ///
    /// @param base_ The base registrar contract.
    /// @param prices_ The pricing oracle contract.
    /// @param reverseRegistrar_ The reverse registrar contract.
    /// @param owner_ The permissioned address initialized as the `owner` in the `Ownable` context.
    /// @param rootNode_ The node for which this registrar manages registrations.
    /// @param rootName_ The name of the root node which this registrar manages.
    constructor(
        BaseRegistrar base_,
        IPriceOracle prices_,
        IReverseRegistrar reverseRegistrar_,
        address owner_,
        bytes32 rootNode_,
        string memory rootName_,
        address paymentReceiver_
    ) {
        base = base_;
        prices = prices_;
        reverseRegistrar = reverseRegistrar_;
        rootNode = rootNode_;
        rootName = rootName_;
        paymentReceiver = paymentReceiver_;
        _initializeOwner(owner_);
        reverseRegistrar.claim(owner_);
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
        discounts[details.key] = details;
        _updateActiveDiscounts(details.key, details.active);
        emit DiscountUpdated(details.key, details);
    }

    /// @notice Allows the `owner` to set the pricing oracle contract.
    ///
    /// @dev Emits `PriceOracleUpdated` after setting the `prices` contract.
    ///
    /// @param prices_ The new pricing oracle.
    function setPriceOracle(IPriceOracle prices_) external onlyOwner {
        prices = prices_;
        emit PriceOracleUpdated(address(prices_));
    }

    /// @notice Allows the `owner` to set the reverse registrar contract.
    ///
    /// @dev Emits `ReverseRegistrarUpdated` after setting the `reverseRegistrar` contract.
    ///
    /// @param reverse_ The new reverse registrar contract.
    function setReverseRegistrar(IReverseRegistrar reverse_) external onlyOwner {
        reverseRegistrar = reverse_;
        emit ReverseRegistrarUpdated(address(reverse_));
    }

    /// @notice Allows the `owner` to set the stored `launchTime`.
    ///
    /// @param launchTime_ The new launch time timestamp.
    function setLaunchTime(uint256 launchTime_) external onlyOwner {
        launchTime = launchTime_;
    }

    /// @notice Allows the `owner` to set the reverse registrar contract.
    ///
    /// @dev Emits `PaymentReceiverUpdated` after setting the `paymentReceiver` address.
    ///
    /// @param paymentReceiver_ The new payment receiver address.
    function setPaymentReceiver(address paymentReceiver_) external onlyOwner {
        if (paymentReceiver_ == address(0)) revert InvalidPaymentReceiver();
        paymentReceiver = paymentReceiver_;
        emit PaymentReceiverUpdated(paymentReceiver_);
    }

    /// @notice Checks whether any of the provided addresses have registered with a discount.
    ///
    /// @param addresses The array of addresses to check for discount registration.
    ///
    /// @return `true` if any of the addresses have already registered with a discount, else `false`.
    function hasRegisteredWithDiscount(address[] memory addresses) external view returns (bool) {
        for (uint256 i; i < addresses.length; i++) {
            if (discountedRegistrants[addresses[i]]) {
                return true;
            }
        }
        return false;
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
    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.isAvailable(uint256(label));
    }

    /// @notice Checks the rent price for a provided `name` and `duration`.
    ///
    /// @param name The name to check the rent price of.
    /// @param duration The time that the name would be rented.
    ///
    /// @return price The `Price` tuple containing the base and premium prices respectively, denominated in wei.
    function rentPrice(string memory name, uint256 duration) public view returns (IPriceOracle.Price memory price) {
        bytes32 label = keccak256(bytes(name));
        price = prices.price(name, _getExpiry(uint256(label)), duration);
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
    /// @return price The all-ing price for the discounted name registration, denominated in wei. Returns 0
    ///         if the price of the discount exceeds the nominal registration fee.
    function discountedRegisterPrice(string memory name, uint256 duration, bytes32 discountKey)
        public
        view
        returns (uint256 price)
    {
        DiscountDetails memory discount = discounts[discountKey];
        price = registerPrice(name, duration);
        price = (price >= discount.discount) ? price - discount.discount : 0;
    }

    /// @notice Check which discounts are currently set to `active`.
    ///
    /// @return An array of `DiscountDetails` that are all currently marked as `active`.
    function getActiveDiscounts() external view returns (DiscountDetails[] memory) {
        bytes32[] memory activeDiscountKeys = activeDiscounts.values();
        DiscountDetails[] memory activeDiscountDetails = new DiscountDetails[](activeDiscountKeys.length);
        for (uint256 i; i < activeDiscountKeys.length; i++) {
            activeDiscountDetails[i] = discounts[activeDiscountKeys[i]];
        }
        return activeDiscountDetails;
    }

    /// @notice Enables a caller to register a name.
    ///
    /// @dev Validates the registration details via the `validRegistration` modifier.
    ///     This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function register(RegisterRequest calldata request) public payable validRegistration(request) {
        uint256 price = registerPrice(request.name, request.duration);

        _validatePayment(price);

        _register(request);

        _refundExcessEth(price);
    }

    /// @notice Enables a caller to register a name and apply a discount.
    ///
    /// @dev In addition to the validation performed for in a `register` request, this method additionally validates
    ///     that msg.sender is eligible for the specified `discountKey` given the provided `validationData`.
    ///     The specific encoding of `validationData` is specified in the implementation of the `discountValidator`
    ///     that is being called.
    ///     Emits `RegisteredWithDiscount` upon successful registration.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    /// @param discountKey The uuid of the discount being accessed.
    /// @param validationData Data necessary to perform the associated discount validation.
    function discountedRegister(RegisterRequest calldata request, bytes32 discountKey, bytes calldata validationData)
        public
        payable
        validRegistration(request)
        discountAvailable
    {
        _validateDiscount(discountKey, validationData);
    
        uint256 price = discountedRegisterPrice(request.name, request.duration, discountKey);

        _validatePayment(price);

        discountedRegistrants[msg.sender] = true;
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
        bytes32 labelhash = keccak256(bytes(name));
        uint256 tokenId = uint256(labelhash);
        IPriceOracle.Price memory price = rentPrice(name, duration);

        _validatePayment(price.base);

        uint256 expires = base.renew(tokenId, duration);

        _refundExcessEth(price.base);

        emit NameRenewed(name, labelhash, expires);
    }

    /// @notice Internal helper for validating ETH payments
    ///
    /// @dev Emits `ETHPaymentProcessed` after validating the payment.
    ///
    /// @param price The expected value.
    function _validatePayment(uint256 price) internal {
        if (msg.value < price) {
            revert InsufficientValue();
        }
        emit ETHPaymentProcessed(msg.sender, price);
    }

    /// @notice Helper for deciding whether to include a launch-premium.
    ///
    /// @dev If the token returns a `0` expiry time, it hasn't been registered before. On launch, this will be true for all
    ///     names. Use the `launchTime` to establish a premium price around the actual launch time.
    ///
    /// @param tokenId The ID of the token to check for expiry.
    ///
    /// @return expires Returns the expiry + GRACE_PERIOD for previously registered names, else `launchTime`.
    function _getExpiry(uint256 tokenId) internal view returns (uint256 expires) {
        expires = base.nameExpires(tokenId);
        if (expires == 0) {
            return launchTime;
        }
        return expires + GRACE_PERIOD;
    }

    /// @notice Shared registartion logic for both `register()` and `discountedRegister()`.
    ///
    /// @dev Will set records in the specified resolver if the resolver address is non zero and there is `data` in the `request`.
    ///     Will set the reverse record's owner as msg.sender if `reverseRecord` is `true`.
    ///     Emits `NameRegistered` upon successful registration.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function _register(RegisterRequest calldata request) internal {
        uint256 expires = base.registerWithRecord(
            uint256(keccak256(bytes(request.name))), request.owner, request.duration, request.resolver, 0
        );

        if (request.data.length > 0) {
            _setRecords(request.resolver, keccak256(bytes(request.name)), request.data);
        }

        if (request.reverseRecord) {
            _setReverseRecord(request.name, request.resolver, msg.sender);
        }

        emit NameRegistered(request.name, keccak256(bytes(request.name)), request.owner, expires);
    }

    /// @notice Refunds any remaining `msg.value` after processing a registration or renewal given`price`.
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
    /// @param label The keccak256 namehash for the specified name.
    /// @param data  The abi encoded calldata records that will be used in the multicallable resolver.
    function _setRecords(address resolverAddress, bytes32 label, bytes[] calldata data) internal {
        bytes32 nodehash = keccak256(abi.encodePacked(rootNode, label));
        L2Resolver resolver = L2Resolver(resolverAddress);
        resolver.multicallWithNodeCheck(nodehash, data);
    }

    /// @notice Sets the reverse record to `owner` for a specified `name` on the specified `resolver.
    ///
    /// @param name The specified name.
    /// @param resolver The resolver to set the reverse record on.
    /// @param owner  The owner of the reverse record.
    function _setReverseRecord(string memory name, address resolver, address owner) internal {
        reverseRegistrar.setNameForAddr(msg.sender, owner, resolver, string.concat(name, rootName));
    }

    /// @notice Helper method for updating the `activeDiscounts` enumerable set.
    ///
    /// @dev Adds the discount `key` to the set if it is active or removes if it is inactive.
    ///
    /// @param key The uuid of the discount.
    /// @param active Whether the specified discount is active or not.
    function _updateActiveDiscounts(bytes32 key, bool active) internal {
        active ? activeDiscounts.add(key) : activeDiscounts.remove(key);
    }

    /// @notice Calls the associated discount validator with `msg.sender` and `validationData`.
    /// 
    /// @dev This method calls `validateDiscountRegistration` which may revert with `DiscountValidator.InvalidDiscount`.
    ///
    /// @param discountKey unique identifier for the discount.
    /// @param validationData validation data required for discount. 
    function _validateDiscount(bytes32 discountKey, bytes calldata validationData) internal {
        DiscountDetails memory details = discounts[discountKey];
        if(!details.active) revert InactiveDiscount(discountKey);

        DiscountValidator validator = DiscountValidator(details.discountValidator);
        validator.validateDiscountRegistration(msg.sender, validationData);
    }

    /// @notice Allows anyone to withdraw the eth accumulated on this contract back to the `paymentReceiver`.
    function withdrawETH() public {
        (bool sent,) = payable(paymentReceiver).call{value: (address(this).balance)}("");
        if (!sent) revert TransferFailed();
    }

    /// @notice Allows the owner to recover ERC20 tokens sent to the contract by mistake.
    ///
    /// @param _to The address to send the tokens to.
    /// @param _token The address of the ERC20 token to recover
    /// @param _amount The amount of tokens to recover.
    function recoverFunds(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
