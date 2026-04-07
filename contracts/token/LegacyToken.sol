// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Legacy fixed-supply ERC20 token used to model a pre-existing deployed asset that cannot be redeployed.
/// @dev All supply is minted in the constructor and no mint function exists after deployment to preserve fixed-supply behavior.
contract LegacyToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 10 ** 18;

    /// @notice Deploys the legacy token and mints the fixed distribution to historical holder addresses.
    /// @dev Uses an assert at the end to guarantee constructor mint accounting always equals TOTAL_SUPPLY.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) Ownable() {
        _mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 4_000_000 * 10 ** 18);
        _mint(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 2_000_000 * 10 ** 18);
        _mint(0x90F79bf6EB2c4f870365E785982E1f101E93b906, 2_000_000 * 10 ** 18);
        _mint(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, 1_000_000 * 10 ** 18);
        _mint(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, 1_000_000 * 10 ** 18);

        assert(totalSupply() == TOTAL_SUPPLY);
    }
}
