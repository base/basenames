// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SignatureDiscountValidator} from "src/L2/discounts/SignatureDiscountValidator.sol";
import {SybilResistanceVerifier} from "src/lib/SybilResistanceVerifier.sol";
import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";

contract TestSDV is Script {
    
    address SIGNER = 0x7d478B0b34d66c7bE28f01B6E865eFd395594794;
    address USER = 0xE6Cec78310ADeC1D6642CfbE8827745bCa141070;
    address OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    SignatureDiscountValidator validator;

    function deploy() public {
        vm.prank(OWNER);
        validator = new SignatureDiscountValidator(OWNER, SIGNER);
        console.logAddress(address(validator));
    }

    function validate(bytes calldata data) public {
        deploy();
        bool ret = validator.isValidDiscountRegistration(USER, data);
        console.log(ret);
    }

    // function signature(uint64 expiry, bytes calldata sig) public {
    //     vm.warp(expiry-1);
    //     bytes memory validationData = abi.encode(USER, expiry, sig);
    //     (, bytes memory ret) = address(this).staticcall(abi.encodeWithSelector(I.verifier.selector, validationData)); 
    //     console.logBytes(ret);
    // }
}