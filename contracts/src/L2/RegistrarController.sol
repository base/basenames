// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";

import {BASE_ETH_NODE} from "src/util/Constants.sol";
import {BaseRegistrar} from "./BaseRegistrar.sol";
import {IDiscountValidator} from "./interface/IDiscountValidator.sol";
import {IPriceOracle} from "./interface/IPriceOracle.sol";
import {L2Resolver} from "./L2Resolver.sol";
import {ReverseRegistrar} from "./ReverseRegistrar.sol";

// @TODO add renew with discount flow
// @TODO ++ Availability state check

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract RegistrarController is Ownable, ReverseClaimer {
    using StringUtils for *;
    using SafeERC20 for IERC20;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    struct RegisterRequest {
        string name;
        address owner;
        uint256 duration;
        address resolver;
        bytes[] data;
        bool reverseRecord;
    }

    struct DiscountDetails {
        bool active;
        address discountValidator;
        uint256 discount; // denom in wei
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    BaseRegistrar immutable base;
    IPriceOracle public immutable prices;
    ReverseRegistrar public immutable reverseRegistrar;
    INameWrapper public immutable nameWrapper;
    IERC20 public immutable usdc;
    EnumerableSetLib.Bytes32Set internal activeDiscounts;
    mapping(bytes32 => DiscountDetails) public discounts;
    mapping(address => bool) public discountedRegistrants;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    uint256 private constant MIN_NAME_LENGTH = 3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERRORS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error AlreadyClaimedWithDiscount(address sender);
    error NameNotAvailable(string name);
    error DurationTooShort(uint256 duration);
    error ResolverRequiredWhenDataSupplied();
    error InactiveDiscount(bytes32 key);
    error InsufficientValue();
    error InvalidDiscount(bytes32 key, bytes data);
    error InvalidDiscountAmount(bytes32 key, uint256 amount);
    error InvalidValidator(bytes32 key, address validator);
    error TransferFailed();
    error Unauthorised(bytes32 node);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event ETHPaymentProcessed(address indexed payee, uint256 price);
    event RegisteredWithDiscount(address indexed registrant, bytes32 indexed discountKey);
    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 expires);
    event NameRenewed(string name, bytes32 indexed label, uint256 expires);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MODIFIERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
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

    modifier validateDiscount(bytes32 discountKey, bytes calldata validationData) {
        if (discountedRegistrants[msg.sender]) revert AlreadyClaimedWithDiscount(msg.sender);
        DiscountDetails memory details = discounts[discountKey];

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
    constructor(
        BaseRegistrar base_,
        IPriceOracle prices_,
        IERC20 usdc_,
        ReverseRegistrar reverseRegistrar_,
        INameWrapper nameWrapper_,
        ENS ens
    ) ReverseClaimer(ens, msg.sender) {
        base = base_;
        prices = prices_;
        usdc = usdc_;
        reverseRegistrar = reverseRegistrar_;
        nameWrapper = nameWrapper_;
    }

    function hasRegisteredWithDiscount(address[] memory addresses) public view returns (bool) {
        for (uint256 i; i < addresses.length; i++) {
            if (discountedRegistrants[addresses[i]]) {
                return true;
            }
        }
        return false;
    }

    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= MIN_NAME_LENGTH;
    }

    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function rentPrice(string memory name, uint256 duration) public view returns (IPriceOracle.Price memory price) {
        bytes32 label = keccak256(bytes(name));
        price = prices.price(name, base.nameExpires(uint256(label)), duration);
    }

    function registerPrice(string memory name, uint256 duration) public view returns (uint256) {
        IPriceOracle.Price memory price = rentPrice(name, duration);
        return price.base + price.premium;
    }

    function getActiveDiscounts() external view returns (DiscountDetails[] memory) {
        bytes32[] memory activeDiscountKeys = activeDiscounts.values();
        DiscountDetails[] memory activeDiscountDetails = new DiscountDetails[](activeDiscountKeys.length);
        for (uint256 i; i < activeDiscountKeys.length; i++) {
            activeDiscountDetails[i] = discounts[activeDiscountKeys[i]];
        }
        return activeDiscountDetails;
    }

    function setDiscountDetails(bytes32 key, DiscountDetails memory details) external onlyOwner {
        if (details.discount == 0) revert InvalidDiscountAmount(key, details.discount);
        if (details.discountValidator == address(0)) revert InvalidValidator(key, details.discountValidator);
        discounts[key] = details;
        _updateActiveDiscounts(key, details.active);
    }

    function _updateActiveDiscounts(bytes32 key, bool active) internal {
        active ? activeDiscounts.add(key) : activeDiscounts.remove(key);
    }

    function discountRentPrice(string memory name, uint256 duration, bytes32 discountKey)
        public
        view
        returns (uint256 price)
    {
        DiscountDetails memory discount = discounts[discountKey];
        price = registerPrice(name, duration);
        price = (price >= discount.discount) ? price - discount.discount : 0;
    }

    function registerETH(RegisterRequest calldata request, uint16 ownerControlledFuses)
        public
        payable
        validRegistration(request)
    {
        uint256 price = registerPrice(request.name, request.duration);

        _validateETHPayment(price);

        _register(request, ownerControlledFuses);

        _refundExcessEth(price);
    }

    function discountedRegisterETH(
        RegisterRequest calldata request,
        uint16 ownerControlledFuses,
        bytes32 discountKey,
        bytes calldata validationData
    ) public payable validateDiscount(discountKey, validationData) validRegistration(request) {
        uint256 price = discountRentPrice(request.name, request.duration, discountKey);

        _validateETHPayment(price);

        _register(request, ownerControlledFuses);
        discountedRegistrants[msg.sender] = true;

        _refundExcessEth(price);

        emit RegisteredWithDiscount(msg.sender, discountKey);
    }

    function renew(string calldata name, uint256 duration) external payable {
        bytes32 labelhash = keccak256(bytes(name));
        uint256 tokenId = uint256(labelhash);
        IPriceOracle.Price memory price = rentPrice(name, duration);

        _validateETHPayment(price.base);

        uint256 expires = nameWrapper.renew(tokenId, duration);

        _refundExcessEth(price.base);

        emit NameRenewed(name, labelhash, expires);
    }

    function _validateETHPayment(uint256 price) internal {
        if (msg.value < price) {
            revert InsufficientValue();
        }
        emit ETHPaymentProcessed(msg.sender, price);
    }

    function _register(RegisterRequest calldata request, uint16 ownerControlledFuses) internal {
        uint256 expires = nameWrapper.registerAndWrapETH2LD(
            request.name, request.owner, request.duration, request.resolver, ownerControlledFuses
        );

        if (request.data.length > 0) {
            _setRecords(request.resolver, keccak256(bytes(request.name)), request.data);
        }

        if (request.reverseRecord) {
            _setReverseRecord(request.name, request.resolver, msg.sender);
        }

        emit NameRegistered(request.name, keccak256(bytes(request.name)), request.owner, expires);
    }

    function _refundExcessEth(uint256 price) internal {
        if (msg.value > price) {
            (bool sent,) = payable(msg.sender).call{value: (msg.value - price)}("");
            if (!sent) revert TransferFailed();
        }
    }

    function _setRecords(address resolverAddress, bytes32 label, bytes[] calldata data) internal {
        // use hardcoded base.eth namehash
        bytes32 nodehash = keccak256(abi.encodePacked(BASE_ETH_NODE, label));
        L2Resolver resolver = L2Resolver(resolverAddress);
        resolver.multicallWithNodeCheck(nodehash, data);
    }

    function _setReverseRecord(string memory name, address resolver, address owner) internal {
        reverseRegistrar.setNameForAddr(msg.sender, owner, resolver, string.concat(name, ".base.eth"));
    }

    function withdrawETH() public {
        (bool sent,) = payable(owner()).call{value: (address(this).balance)}("");
        if (!sent) revert TransferFailed();
    }

    /**
     * @notice Recover ERC20 tokens sent to the contract by mistake.
     * @param _to The address to send the tokens to.
     * @param _token The address of the ERC20 token to recover
     * @param _amount The amount of tokens to recover.
     */
    function recoverFunds(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
