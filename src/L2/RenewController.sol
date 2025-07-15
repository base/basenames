// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IBaseRegistrar} from "./interface/IBaseRegistrar.sol";

contract RenewController is Ownable2Step {
    
    
    uint256 constant ONE_YEAR_S = 365.25 days;

    IBaseRegistrar baseRegistrar;

    /// @notice Emitted when a name is renewed.
    ///
    /// @param name The name that was renewed.
    /// @param label The hashed label of the name.
    /// @param expires The date that the renewed name expires.
    event NameRenewed(string name, bytes32 indexed label, uint256 expires);

    constructor(address owner_, address baseRegistrar_) Ownable(owner_){
        baseRegistrar = IBaseRegistrar(baseRegistrar_);
    }

    function renewBatch(string[] calldata names) external onlyOwner {
        for(uint256 i; i < names.length; i++) {
            string memory name = names[i]; 
            bytes32 labelhash = keccak256(bytes(name));
            uint256 tokenId = uint256(labelhash);
            uint256 expires = baseRegistrar.renew(tokenId, ONE_YEAR_S);
            emit NameRenewed(name, labelhash, expires);
        }
    }

}