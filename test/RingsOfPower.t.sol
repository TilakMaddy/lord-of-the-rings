// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";

contract RingsOfPowerTest is Test {
    RingsOfPower public rings;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    address public sauron;
    address public gandalf;
    address public frodo;
    address public aragorn;
    address public gollum;

    function setUp() public {
        sauron = address(this);
        gandalf = makeAddr("gandalf");
        frodo = makeAddr("frodo");
        aragorn = makeAddr("aragorn");
        gollum = makeAddr("gollum");

        rings = new RingsOfPower();
    }

    // ─── Forging Tests ────────────────────────────────────────────────

    function test_ForgeElvenRings() public {
        rings.forge(1, gandalf); // Narya
        rings.forge(2, gandalf); // Nenya
        rings.forge(3, gandalf); // Vilya

        assertEq(rings.ownerOf(1), gandalf);
        assertEq(rings.ownerOf(2), gandalf);
        assertEq(rings.ownerOf(3), gandalf);
        assertEq(rings.balanceOf(gandalf), 3);
        assertEq(rings.ringsForged(), 3);
    }

    function test_ForgeDwarvenRings() public {
        for (uint256 i = 4; i <= 10; i++) {
            rings.forge(i, aragorn);
        }
        assertEq(rings.balanceOf(aragorn), 7);
    }

    function test_ForgeMortalRings() public {
        for (uint256 i = 11; i <= 19; i++) {
            rings.forge(i, frodo);
        }
        assertEq(rings.balanceOf(frodo), 9);
    }

    function test_ForgeTheOneRing() public {
        rings.forge(20, sauron);
        assertEq(rings.ownerOf(20), sauron);

        RingsOfPower.Ring memory ring = rings.getRing(20);
        assertEq(ring.name, "The One Ring");
        assertEq(ring.power, 100);
        assertTrue(ring.forged);
    }

    function test_RevertForge_NotSauron() public {
        vm.prank(frodo);
        vm.expectRevert(RingsOfPower.NotSauron.selector);
        rings.forge(1, frodo);
    }

    function test_RevertForge_AlreadyForged() public {
        rings.forge(1, gandalf);
        vm.expectRevert(RingsOfPower.RingAlreadyForged.selector);
        rings.forge(1, frodo);
    }

    function test_RevertForge_InvalidRingId() public {
        vm.expectRevert(RingsOfPower.InvalidRingId.selector);
        rings.forge(0, gandalf);

        vm.expectRevert(RingsOfPower.InvalidRingId.selector);
        rings.forge(21, gandalf);
    }

    // ─── Ring Info Tests ──────────────────────────────────────────────

    function test_RingRaces() public view {
        assertEq(uint256(rings.getRingRace(1)), uint256(RingsOfPower.Race.Elven));
        assertEq(uint256(rings.getRingRace(5)), uint256(RingsOfPower.Race.Dwarven));
        assertEq(uint256(rings.getRingRace(15)), uint256(RingsOfPower.Race.Mortal));
        assertEq(uint256(rings.getRingRace(20)), uint256(RingsOfPower.Race.TheOneRing));
    }

    function test_RingPowers() public view {
        assertEq(rings.getRingPower(1), 90); // Narya
        assertEq(rings.getRingPower(3), 92); // Vilya (most powerful elven ring)
        assertEq(rings.getRingPower(20), 100); // The One Ring
    }

    function test_IsBearer() public {
        assertFalse(rings.isBearer(gandalf));
        rings.forge(1, gandalf);
        assertTrue(rings.isBearer(gandalf));
    }

    // ─── Corruption Tests ─────────────────────────────────────────────

    function test_CorruptionIncreasesOverTime() public {
        rings.forge(11, frodo); // Mortal ring, high corruption rate

        vm.roll(block.number + 100);
        uint256 corruption = rings.calculateCorruption(frodo);
        assertEq(corruption, 7); // 100 blocks * 7 rate / 100
    }

    function test_ElvenCorruptionIsLow() public {
        rings.forge(1, gandalf); // Elven ring, low corruption rate

        vm.roll(block.number + 100);
        uint256 corruption = rings.calculateCorruption(gandalf);
        assertEq(corruption, 1); // 100 blocks * 1 rate / 100
    }

    function test_OneRingCorruptionIsHigh() public {
        rings.forge(20, frodo);

        vm.roll(block.number + 100);
        uint256 corruption = rings.calculateCorruption(frodo);
        assertEq(corruption, 15); // 100 blocks * 15 rate / 100
    }

    function test_BecomeWraith() public {
        rings.forge(20, frodo);

        // Need enough blocks for corruption to reach 100
        // 100 threshold / 15 rate * 100 = ~667 blocks
        vm.roll(block.number + 700);

        rings.tickCorruption(frodo);

        (uint256 corruptionLevel,, bool isWraith) = rings.bearers(frodo);
        assertTrue(isWraith);
        assertTrue(corruptionLevel >= 100);
    }

    function test_CleansCorruption() public {
        rings.forge(20, frodo);
        vm.roll(block.number + 200);

        rings.tickCorruption(frodo);

        (uint256 corruptionBefore,,) = rings.bearers(frodo);
        assertTrue(corruptionBefore > 0);

        rings.cleanse(frodo, corruptionBefore);

        (uint256 corruptionAfter,,) = rings.bearers(frodo);
        assertEq(corruptionAfter, 0);
    }

    function test_RevertForge_BearerIsWraith() public {
        rings.forge(20, frodo);
        vm.roll(block.number + 700);
        rings.tickCorruption(frodo);

        // Can't forge a new ring for a wraith
        vm.expectRevert(RingsOfPower.BearerIsWraith.selector);
        rings.forge(1, frodo);
    }

    // ─── The One Ring Powers ──────────────────────────────────────────

    function test_Dominate() public {
        rings.forge(1, gandalf);
        rings.forge(20, sauron);

        assertEq(rings.ownerOf(1), gandalf);

        rings.dominate(1);

        assertEq(rings.ownerOf(1), sauron);
        assertEq(rings.balanceOf(gandalf), 0);
        assertEq(rings.balanceOf(sauron), 2);
    }

    function test_SeeAllRings() public {
        rings.forge(1, gandalf);
        rings.forge(2, gandalf);
        rings.forge(3, gandalf);
        rings.forge(20, sauron);

        uint256[] memory gandalfRings = rings.seeAllRings(gandalf);
        assertEq(gandalfRings.length, 3);
    }

    function test_RevertDominate_NotOneRingBearer() public {
        rings.forge(1, gandalf);
        rings.forge(20, frodo);

        vm.prank(gandalf);
        vm.expectRevert(RingsOfPower.NotTheOneRingBearer.selector);
        rings.dominate(1);
    }

    function test_RevertDominate_Self() public {
        rings.forge(20, sauron);

        vm.expectRevert(RingsOfPower.CannotDominateSelf.selector);
        rings.dominate(20);
    }

    // ─── Destroy The One Ring ─────────────────────────────────────────

    function test_CastIntoMountDoom() public {
        rings.forge(20, frodo);

        vm.prank(frodo);
        rings.castIntoMountDoom();

        assertTrue(rings.theOneRingDestroyed());

        // Token is burned
        vm.expectRevert();
        rings.ownerOf(20);
    }

    function test_DestroyingOneRingCleansesCorruption() public {
        rings.forge(20, frodo);

        vm.roll(block.number + 200);
        rings.tickCorruption(frodo);

        (uint256 corruptionBefore,,) = rings.bearers(frodo);
        assertTrue(corruptionBefore > 0);

        vm.prank(frodo);
        rings.castIntoMountDoom();

        (uint256 corruptionAfter,, bool isWraith) = rings.bearers(frodo);
        assertEq(corruptionAfter, 0);
        assertFalse(isWraith);
    }

    // ─── Transfer Tests ───────────────────────────────────────────────

    function test_TransferRingUpdatesBearerSince() public {
        rings.forge(1, gandalf);
        uint256 forgeBlock = block.number;

        vm.roll(block.number + 50);

        vm.prank(gandalf);
        rings.transferFrom(gandalf, frodo, 1);

        assertEq(rings.ownerOf(1), frodo);
        assertEq(rings.ringBearerSince(1), forgeBlock + 50);
    }

    function test_ForgeAllTwentyRings() public {
        for (uint256 i = 1; i <= 20; i++) {
            rings.forge(i, gandalf);
        }
        assertEq(rings.balanceOf(gandalf), 20);
        assertEq(rings.ringsForged(), 20);
    }
}
