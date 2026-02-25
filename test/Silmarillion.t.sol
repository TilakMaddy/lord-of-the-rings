// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {Silmarillion} from "../src/Silmarillion.sol";

contract SilmarillionTest is Test {
    RingsOfPower public rings;
    Silmarillion public sil;

    address public iluvatar; // deployer / owner
    address public feanor;
    address public morgoth;
    address public fingolfin;

    function setUp() public {
        iluvatar = address(this);
        feanor = makeAddr("feanor");
        morgoth = makeAddr("morgoth");
        fingolfin = makeAddr("fingolfin");

        rings = new RingsOfPower();
        sil = new Silmarillion(address(rings));

        // Distribute some SIL for testing
        require(sil.transfer(feanor, 100_000 ether), "Transfer failed");
        require(sil.transfer(fingolfin, 100_000 ether), "Transfer failed");
    }

    function test_InitialSupply() public view {
        assertEq(sil.totalSupply(), 3_000_000 ether);
        assertEq(sil.name(), "Silmarillion");
        assertEq(sil.symbol(), "SIL");
    }

    function test_MorgothTax() public {
        uint256 hoardBefore = sil.morgothsHoard();
        uint256 transferAmount = 10_000 ether;
        uint256 expectedTax = (transferAmount * 100) / 10000; // 1%

        vm.prank(feanor);
        require(sil.transfer(fingolfin, transferAmount), "Transfer failed");

        assertEq(sil.morgothsHoard() - hoardBefore, expectedTax);
    }

    function test_RingBearerReward() public {
        rings.forge(1, feanor); // Narya - power 90

        uint256 balBefore = sil.balanceOf(feanor);

        // Advance enough blocks
        vm.roll(block.number + 7200); // 1 day

        vm.prank(feanor);
        sil.claimRingBearerReward();

        // feanor should have received minted reward tokens
        assertTrue(sil.balanceOf(feanor) > balBefore);
    }

    function test_RevertClaim_NotRingBearer() public {
        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert(Silmarillion.NotARingBearer.selector);
        sil.claimRingBearerReward();
    }

    function test_RevertClaim_TooSoon() public {
        rings.forge(1, feanor);

        vm.roll(block.number + 7200);
        vm.prank(feanor);
        sil.claimRingBearerReward();

        // Try again immediately
        vm.prank(feanor);
        vm.expectRevert(Silmarillion.NothingToClaim.selector);
        sil.claimRingBearerReward();
    }

    function test_AuthorizeMinter() public {
        address gameContract = makeAddr("game");
        sil.authorizeMinter(gameContract);
        assertTrue(sil.isMinter(gameContract));

        uint256 balBefore = sil.balanceOf(feanor);
        vm.prank(gameContract);
        sil.mint(feanor, 1000 ether);

        assertEq(sil.balanceOf(feanor) - balBefore, 1000 ether);
    }

    function test_RevokeMinter() public {
        address gameContract = makeAddr("game");
        sil.authorizeMinter(gameContract);
        sil.revokeMinter(gameContract);
        assertFalse(sil.isMinter(gameContract));

        vm.prank(gameContract);
        vm.expectRevert(Silmarillion.NotAuthorizedMinter.selector);
        sil.mint(feanor, 1000 ether);
    }

    function test_SwearOath() public {
        vm.startPrank(feanor);
        sil.swearOath(50_000 ether, 50_400); // Min lock duration

        Silmarillion.FeanorsOath memory oath = sil.getOath(feanor);
        assertEq(oath.amount, 50_000 ether);
        assertEq(oath.multiplier, 100); // Min multiplier
        vm.stopPrank();
    }

    function test_FulfillOath() public {
        vm.startPrank(feanor);
        sil.swearOath(50_000 ether, 50_400);

        vm.roll(block.number + 50_401); // Past lock period

        uint256 balBefore = sil.balanceOf(feanor);
        sil.fulfillOath();
        uint256 balAfter = sil.balanceOf(feanor);

        // Should get back 50_000 + bonus (0% for min lock = 0 bonus)
        assertTrue(balAfter > balBefore);
        assertEq(balAfter - balBefore, 50_000 ether); // 100 multiplier = 0% bonus
        vm.stopPrank();
    }

    function test_BreakOath_Penalty() public {
        vm.startPrank(feanor);
        sil.swearOath(50_000 ether, 50_400);

        uint256 balBefore = sil.balanceOf(feanor);
        sil.breakOath();
        uint256 balAfter = sil.balanceOf(feanor);

        // Should get back 50% (penalty is 50%)
        assertEq(balAfter - balBefore, 25_000 ether);
        vm.stopPrank();
    }

    function test_RevertOath_AlreadySworn() public {
        vm.startPrank(feanor);
        sil.swearOath(10_000 ether, 50_400);

        vm.expectRevert(Silmarillion.OathAlreadySworn.selector);
        sil.swearOath(10_000 ether, 50_400);
        vm.stopPrank();
    }

    function test_Burn() public {
        vm.prank(feanor);
        sil.burn(1000 ether);

        assertEq(sil.totalBurned(), 1000 ether);
    }

    function test_SetMorgothsVault() public {
        sil.setMorgothsVault(morgoth);
        assertEq(sil.morgothsVault(), morgoth);
    }
}
