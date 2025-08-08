//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";

import {AttestationValidator} from "src/L2/discounts/AttestationValidator.sol";
import {BaseRegistrar} from "src/L2/BaseRegistrar.sol";
import {CBIdDiscountValidator} from "src/L2/discounts/CBIdDiscountValidator.sol";
import {NameEncoder} from "ens-contracts/utils/NameEncoder.sol";
import {ExponentialPremiumPriceOracle} from "src/L2/ExponentialPremiumPriceOracle.sol";
import {ERC1155DiscountValidator} from "src/L2/discounts/ERC1155DiscountValidator.sol";
import {IBaseRegistrar} from "src/L2/interface/IBaseRegistrar.sol";
import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {L1Resolver} from "src/L1/L1Resolver.sol";
import {L2Resolver} from "src/L2/L2Resolver.sol";
import {LaunchAuctionPriceOracle} from "src/L2/LaunchAuctionPriceOracle.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";
import {Registry} from "src/L2/Registry.sol";
import {ReverseRegistrar} from "src/L2/ReverseRegistrar.sol";

import {
    ETH_NODE,
    BASE_ETH_NODE,
    REVERSE_NODE,
    BASE_REVERSE_NODE,
    GRACE_PERIOD,
    BASE_ETH_NAME
} from "src/util/Constants.sol";

contract IntegrationTestBase is Test {
    address owner;
    address signer;
    address alice;
    address payments;

    L1Resolver l1Resolver;

    Registry registry;
    BaseRegistrar baseRegistrar;
    RegistrarController registrarController;
    L2Resolver defaultL2Resolver;
    ReverseRegistrar reverseRegistrar;
    LaunchAuctionPriceOracle launchAuctionPriceOracle;
    ExponentialPremiumPriceOracle exponentialPremiumPriceOracle;

    AttestationValidator attestationValidator;
    CBIdDiscountValidator cBIdDiscountValidator;
    ERC1155DiscountValidator eRC1155DiscountValidator;

    bytes32 constant ROOT_NODE = bytes32(0);
    bytes32 constant ETH_LABEL = 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 constant BASE_LABEL = 0xf1f3eb40f5bc1ad1344716ced8b8a0431d840b5783aea1fd01786bc26f35ac0f;
    bytes32 constant REVERSE_LABEL = 0xdec08c9dbbdd0890e300eb5062089b2d4b1c40e3673bbccb5423f7b37dcf9a9c;
    bytes32 constant ADDR_LABEL = 0xe5e14487b78f85faa6e1808e89246cf57dd34831548ff2e6097380d98db2504a;

    uint256 constant LAUNCH_AUCTION_START_PRICE = 100 ether;
    uint256 constant LAUNCH_AUCTION_DURATION_HOURS = 36;
    uint256 constant LAUNCH_TIME = 1723420800; // Monday, August 12, 2024 12:00:00 AM GMT

    uint256 constant EXPIRY_AUCTION_START_PRICE = 1000 ether;
    uint256 constant EXPIRY_AUCTION_DURATION_DAYS = 21;

    function setUp() public virtual {
        owner = makeAddr("owner");
        signer = makeAddr("signer");
        alice = makeAddr("alice");
        payments = makeAddr("payments");

        registry = new Registry(owner);
        reverseRegistrar = new ReverseRegistrar(registry, owner, BASE_REVERSE_NODE);

        launchAuctionPriceOracle =
            new LaunchAuctionPriceOracle(_getBasePrices(), LAUNCH_AUCTION_START_PRICE, LAUNCH_AUCTION_DURATION_HOURS);

        baseRegistrar = new BaseRegistrar(registry, owner, BASE_ETH_NODE, "", "");

        _establishNamespaces();

        registrarController = new RegistrarController(
            baseRegistrar,
            IPriceOracle(launchAuctionPriceOracle),
            IReverseRegistrar(address(reverseRegistrar)),
            owner,
            BASE_ETH_NODE,
            ".base.eth",
            payments
        );

        vm.prank(owner);
        reverseRegistrar.setControllerApproval(address(registrarController), true);

        defaultL2Resolver = new L2Resolver(registry, address(registrarController), address(reverseRegistrar), owner);

        vm.prank(owner);
        reverseRegistrar.setDefaultResolver(address(defaultL2Resolver));

        vm.prank(owner);
        reverseRegistrar.setName("rootOwner");

        vm.prank(owner);
        baseRegistrar.addController(address(registrarController));

        vm.prank(owner);
        registrarController.setLaunchTime(LAUNCH_TIME);
        vm.warp(LAUNCH_TIME);
    }

    function _establishNamespaces() internal {
        //  establish base.eth namespace and assign ownership of base.eth to the registrar controller
        vm.startPrank(owner);
        registry.setSubnodeOwner(ROOT_NODE, ETH_LABEL, owner);
        registry.setSubnodeOwner(ETH_NODE, BASE_LABEL, address(baseRegistrar));

        // establish 80002105.reverse namespace and assign ownership to the reverse registrar
        registry.setSubnodeOwner(ROOT_NODE, REVERSE_LABEL, owner);
        registry.setSubnodeOwner(REVERSE_NODE, keccak256("80002105"), address(reverseRegistrar));
        vm.stopPrank();
    }

    function _getBasePrices() internal pure returns (uint256[] memory) {
        uint256[] memory rentPrices = new uint256[](6);
        rentPrices[0] = 316_808_781_402;
        rentPrices[1] = 31_680_878_140;
        rentPrices[2] = 3_168_087_814;
        rentPrices[3] = 316_808_781;
        rentPrices[4] = 31_680_878;
        rentPrices[5] = 3_168_087; // 3,168,808.781402895 = 1e14 / (365.25 * 24 * 3600)
        return rentPrices;
    }

    function _registerAlice() internal returns (bytes32) {
        string memory name = "alice";
        string memory fullName = string.concat(name, ".base.eth");
        uint256 duration = 365.25 days;

        uint256 registerPrice = registrarController.registerPrice(name, duration);
        vm.deal(alice, registerPrice);

        // Establish legacy forward resolution data on registration
        (, bytes32 node) = NameEncoder.dnsEncodeName(fullName);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(AddrResolver.setAddr.selector, node, alice);

        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: name,
            owner: alice,
            duration: duration,
            resolver: address(defaultL2Resolver),
            data: data,
            reverseRecord: true
        });

        registrarController.register{value: registerPrice}(request);
        return node;
    }
}

interface AddrResolver {
    function setAddr(bytes32 node, address a) external;
}
