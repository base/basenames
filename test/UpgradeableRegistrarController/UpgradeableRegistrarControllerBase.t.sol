// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {BaseRegistrar} from "src/L2/BaseRegistrar.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Registry} from "src/L2/Registry.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";

import {MockBaseRegistrar} from "test/mocks/MockBaseRegistrar.sol";
import {MockDiscountValidator} from "test/mocks/MockDiscountValidator.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockNameResolver} from "test/mocks/MockNameResolver.sol";
import {MockPriceOracle} from "test/mocks/MockPriceOracle.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {MockRegistrarController} from "test/mocks/MockRegistrarController.sol";
import {BASE_ETH_NODE, REVERSE_NODE} from "src/util/Constants.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import "forge-std/console.sol";

contract UpgradeableRegistrarControllerBase is Test {
    UpgradeableRegistrarController public controllerImpl;
    UpgradeableRegistrarController public controller;
    TransparentUpgradeableProxy public proxy;

    MockBaseRegistrar public base;
    MockReverseRegistrar public reverse;
    MockPriceOracle public prices;
    Registry public registry;
    MockPublicResolver public resolver;
    MockRegistrarController public legacyController;
    MockNameResolver public legacyL2Resolver;
    MockL2ReverseRegistrar public l2ReverseRegistrar;

    address owner = makeAddr("owner"); // Ownable owner on UpgradeableRegistrarController
    address admin = makeAddr("admin"); // Proxy Admin on TransparentUpgradeableProxy
    address user = makeAddr("user");
    address payments = makeAddr("payments");

    bytes32 public rootNode = BASE_ETH_NODE;
    string public rootName = ".base.eth";
    string public name = "test";
    string public shortName = "t";
    bytes32 public nameLabel = keccak256(bytes(name));
    bytes32 public shortNameLabel = keccak256(bytes(shortName));
    uint256 baseCointype = 0x80000000 | 0x00002105;

    MockDiscountValidator public validator;
    bytes32 public discountKey = keccak256(bytes("default.discount"));
    uint256 discountAmount = 0.1 ether;
    uint256 duration = 365 days;

    function setUp() public {
        base = new MockBaseRegistrar();
        reverse = new MockReverseRegistrar();
        prices = new MockPriceOracle();
        registry = new Registry(owner);
        resolver = new MockPublicResolver();
        validator = new MockDiscountValidator();
        legacyController = new MockRegistrarController(block.timestamp);
        legacyL2Resolver = new MockNameResolver();
        l2ReverseRegistrar = new MockL2ReverseRegistrar();

        _establishNamespace();

        bytes memory controllerInitData = abi.encodeWithSelector(
            UpgradeableRegistrarController.initialize.selector,
            BaseRegistrar(address(base)),
            IPriceOracle(address(prices)),
            IReverseRegistrar(address(reverse)),
            owner,
            rootNode,
            rootName,
            payments,
            address(legacyController),
            address(legacyL2Resolver),
            address(l2ReverseRegistrar)
        );

        vm.prank(owner);
        controllerImpl = new UpgradeableRegistrarController();
        proxy = new TransparentUpgradeableProxy(address(controllerImpl), admin, controllerInitData);
        controller = UpgradeableRegistrarController(address(proxy));
    }

    function _establishNamespace() internal virtual {}

    function _getDefaultDiscount() internal view returns (UpgradeableRegistrarController.DiscountDetails memory) {
        return UpgradeableRegistrarController.DiscountDetails({
            active: true,
            discountValidator: address(validator),
            key: discountKey,
            discount: discountAmount
        });
    }

    function _getDefaultRegisterRequest()
        internal
        view
        virtual
        returns (UpgradeableRegistrarController.RegisterRequest memory)
    {
        uint256[] memory coinTypes = new uint256[](1);
        coinTypes[0] = baseCointype;
        return UpgradeableRegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: duration,
            resolver: address(resolver),
            data: _getDefaultRegisterData(),
            reverseRecord: true,
            coinTypes: coinTypes,
            signatureExpiry: 0,
            signature: ""
        });
    }

    function _getDefaultRegisterData() internal view virtual returns (bytes[] memory data) {
        data = new bytes[](1);
        data[0] = bytes(name);
    }

    modifier whenNotProxyAdmin(address caller, address proxyContract) {
        // The _admin on the Proxy is not exposed externally, although can be loaded from the ERC1967 admin slot
        address proxyAdmin = address(uint160(uint256(vm.load(address(proxyContract), ERC1967Utils.ADMIN_SLOT))));
        vm.assume(caller != proxyAdmin); // proxy admin on transparent upgradeable proxy
        _;
    }
}
