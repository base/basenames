//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseRegistrar} from "src/L2/BaseRegistrar.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";
import {LibString} from "solady/utils/LibString.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {Multicallable} from "ens-contracts/resolvers/Multicallable.sol";
import "ens-contracts/utils/NameEncoder.sol";

import "forge-std/Script.sol";

interface AddrResolver {
    function setAddr(bytes32 node, uint256 cointype, bytes memory addr) external;
}

contract CreateName is Script {
    uint256 pkey = vm.envUint("TESTNET_PRIVATE_KEY");
    address BASE_REGISTRAR = vm.envAddress("TESTNET_BASE_REGISTRAR_ADDR");
    address L2RESOLVER = vm.envAddress("TESTNET_L2_RESOLVER_ADDR");

    address testnetAddr = vm.addr(pkey);
    uint256 constant ETH_COINTYPE = 60;
    uint256 constant BASE_SEPOLIA_COINTYPE = 0x80000000 | 0x00014A34; // 84532

    function run(string memory name, uint256 duration, bool setRecords) external {
        console.log("-------------------------------");
        console.log("Minting name:");
        console.log(name);
        console.log("-------------------------------");

        vm.startBroadcast(pkey);

        bytes32 label = keccak256(bytes(name));
        uint256 id = uint256(label);

        BaseRegistrar(BASE_REGISTRAR).registerOnly(id, testnetAddr, duration);

        if (setRecords) {
            setResolverDetails(name);
        }
    }

    function setResolverDetails(string memory name) public {
        vm.startBroadcast(pkey);

        bytes32 label = keccak256(bytes(name));
        uint256 id = uint256(label);
        BaseRegistrar(BASE_REGISTRAR).renew(id, 3600);

        console.log(BaseRegistrar(BASE_REGISTRAR).nameExpires(id));

        BaseRegistrar(BASE_REGISTRAR).reclaim(id, testnetAddr);

        (, bytes32 node) = NameEncoder.dnsEncodeName(string.concat(name, ".basetest.eth"));
        Multicallable(L2RESOLVER).multicallWithNodeCheck(node, _buildResolverData(node, testnetAddr, name));
    }

    function _buildResolverData(bytes32 node, address addr, string memory name)
        internal
        pure
        returns (bytes[] memory data)
    {
        bytes[] memory multicallData = new bytes[](3);
        multicallData[0] =
            abi.encodeWithSelector(AddrResolver.setAddr.selector, node, ETH_COINTYPE, _addressToBytes(addr));
        multicallData[1] =
            abi.encodeWithSelector(AddrResolver.setAddr.selector, node, BASE_SEPOLIA_COINTYPE, _addressToBytes(addr));
        multicallData[2] =
            abi.encodeWithSelector(NameResolver.setName.selector, node, string.concat(name, ".basetest.eth"));
        return multicallData;
    }

    function _addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
