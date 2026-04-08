// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LegacyToken} from "contracts/token/LegacyToken.sol";

contract LegacyTokenTest is Test {
    LegacyToken internal legacyToken;

    address internal constant HOLDER_1 =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant HOLDER_2 =
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant HOLDER_3 =
        0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant HOLDER_4 =
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address internal constant HOLDER_5 =
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;

    uint256 internal constant DECIMALS = 10 ** 18;

    function setUp() external {
        legacyToken = new LegacyToken("Legacy Token", "LGT");
    }

    function test_InitialSupply() external view {
        uint256 expectedTotalSupply = 10_000_000 * DECIMALS;

        assertEq(legacyToken.totalSupply(), expectedTotalSupply);
        assertEq(legacyToken.balanceOf(HOLDER_1), 4_000_000 * DECIMALS);
        assertEq(legacyToken.balanceOf(HOLDER_2), 2_000_000 * DECIMALS);
        assertEq(legacyToken.balanceOf(HOLDER_3), 2_000_000 * DECIMALS);
        assertEq(legacyToken.balanceOf(HOLDER_4), 1_000_000 * DECIMALS);
        assertEq(legacyToken.balanceOf(HOLDER_5), 1_000_000 * DECIMALS);

        uint256 sum = legacyToken.balanceOf(HOLDER_1) +
            legacyToken.balanceOf(HOLDER_2) +
            legacyToken.balanceOf(HOLDER_3) +
            legacyToken.balanceOf(HOLDER_4) +
            legacyToken.balanceOf(HOLDER_5);

        assertEq(sum, legacyToken.totalSupply());
    }

    function test_Transfer_Success() external {
        uint256 amount = 100 * DECIMALS;

        vm.prank(HOLDER_1);
        bool ok = legacyToken.transfer(HOLDER_2, amount);

        assertTrue(ok);
        assertEq(
            legacyToken.balanceOf(HOLDER_1),
            (4_000_000 * DECIMALS) - amount
        );
        assertEq(
            legacyToken.balanceOf(HOLDER_2),
            (2_000_000 * DECIMALS) + amount
        );
    }

    function test_Transfer_InsufficientBalance() external {
        uint256 amount = 1;

        vm.prank(address(0xBEEF));
        vm.expectRevert();
        bool ok = legacyToken.transfer(HOLDER_1, amount);
        ok;
    }

    function test_TransferFrom_WithApproval() external {
        uint256 amount = 250 * DECIMALS;

        vm.startPrank(HOLDER_1);
        legacyToken.approve(HOLDER_3, amount);
        vm.stopPrank();

        vm.prank(HOLDER_3);
        bool ok = legacyToken.transferFrom(HOLDER_1, HOLDER_2, amount);

        assertTrue(ok);
        assertEq(
            legacyToken.balanceOf(HOLDER_1),
            (4_000_000 * DECIMALS) - amount
        );
        assertEq(
            legacyToken.balanceOf(HOLDER_2),
            (2_000_000 * DECIMALS) + amount
        );
        assertEq(legacyToken.allowance(HOLDER_1, HOLDER_3), 0);
    }

    function test_TransferFrom_WithoutApproval() external {
        vm.prank(HOLDER_3);
        vm.expectRevert();
        bool ok = legacyToken.transferFrom(HOLDER_1, HOLDER_2, 1 * DECIMALS);
        ok;
    }

    function test_ZeroTransfer() external {
        vm.prank(HOLDER_1);
        bool ok = legacyToken.transfer(HOLDER_2, 0);

        assertTrue(ok);
        assertEq(legacyToken.balanceOf(HOLDER_1), 4_000_000 * DECIMALS);
        assertEq(legacyToken.balanceOf(HOLDER_2), 2_000_000 * DECIMALS);
    }
}
