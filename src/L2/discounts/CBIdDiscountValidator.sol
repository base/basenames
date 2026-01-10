//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MerkleProofLib} from "lib/solady/src/utils/MerkleProofLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {DiscountValidator} from "./DiscountValidator.sol";

/// @title Discount Validator for: cb.id
///
/// @notice Implements a simple Merkle Proof validator checking that the claimant is in the stored merkle tree.
///
/// @author Coinbase
contract CBIdDiscountValidator is Ownable, DiscountValidator {
    /// @dev merkle tree root
    bytes32 public root;

    constructor(address owner_, bytes32 root_) {
        _initializeOwner(owner_);
        root = root_;
    }

    /// @notice Allows the owner to update the merkle root.
    ///
    /// @param root_ The new merkle tree root.
    function setRoot(bytes32 root_) external onlyOwner {
        root = root_;
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev The proof data must be encoded as `abi.encode(bytes32[] proof)`.
    ///
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) public view override returns (bool) {
        (bytes32[] memory proof) = abi.decode(validationData, (bytes32[]));
        return MerkleProofLib.verify(proof, root, keccak256(abi.encodePacked(claimer)));
    }
}
