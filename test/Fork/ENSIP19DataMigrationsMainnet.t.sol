// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseMainnetConfig} from "./BaseMainnetConfig.t.sol";
import {AbstractENSIP19DataMigrations} from "./AbstractENSIP19DataMigrations.t.sol";

contract ENSIP19DataMigrationsMainnet is BaseMainnetConfig, AbstractENSIP19DataMigrations {}
