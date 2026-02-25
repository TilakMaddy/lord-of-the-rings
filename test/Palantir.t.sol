// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {Palantir} from "../src/Palantir.sol";

contract PalantirTest is Test {
    RingsOfPower public rings;
    Palantir public palantir;

    address public sauron;
    address public saruman;
    address public denethor;
    address public aragorn;

    function setUp() public {
        sauron = address(this);
        saruman = makeAddr("saruman");
        denethor = makeAddr("denethor");
        aragorn = makeAddr("aragorn");

        rings = new RingsOfPower();
        palantir = new Palantir(address(rings));

        // Give rings to enable stone discovery
        rings.forge(1, saruman);
        rings.forge(2, denethor);
        rings.forge(3, aragorn);

        // Advance past initial cooldown period
        vm.roll(block.number + 100);
    }

    function test_DiscoverStone() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        Palantir.SeeingStone memory s = palantir.getStone(Palantir.Stone.OrthancsStone);
        assertTrue(s.found);
        assertEq(s.keeper, saruman);
    }

    function test_RevertDiscover_NotRingBearer() public {
        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert("Only ring bearers can find Palantiri");
        palantir.discoverStone(Palantir.Stone.OrthancsStone);
    }

    function test_RevertDiscover_AlreadyFound() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        vm.prank(denethor);
        vm.expectRevert(Palantir.StoneAlreadyFound.selector);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);
    }

    function test_TransferStone() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.transferStone(Palantir.Stone.OrthancsStone, aragorn);

        Palantir.SeeingStone memory s = palantir.getStone(Palantir.Stone.OrthancsStone);
        assertEq(s.keeper, aragorn);
    }

    function test_BeginScrying() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.beginScrying(Palantir.Stone.OrthancsStone);

        (address seer,,, bool active) = palantir.activeSessions(saruman);
        assertEq(seer, saruman);
        assertTrue(active);
    }

    function test_ReceiveVision() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.beginScrying(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.receiveVision(denethor, "I see the White City burning!");

        assertEq(palantir.getVisionCount(saruman), 1);
        assertEq(palantir.totalVisions(), 1);
    }

    function test_ScryingCooldown() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.beginScrying(Palantir.Stone.OrthancsStone);

        vm.prank(saruman);
        palantir.receiveVision(denethor, "Vision 1");

        // Try to scry again immediately - should fail
        vm.prank(saruman);
        vm.expectRevert(Palantir.ScryingOnCooldown.selector);
        palantir.beginScrying(Palantir.Stone.OrthancsStone);

        // Wait for cooldown
        vm.roll(block.number + 51);

        vm.prank(saruman);
        palantir.beginScrying(Palantir.Stone.OrthancsStone);
    }

    function test_ElostirionFlatEarthVision() public {
        vm.prank(saruman);
        palantir.discoverStone(Palantir.Stone.ElostirionStone);

        vm.prank(saruman);
        palantir.beginScrying(Palantir.Stone.ElostirionStone);

        // The Elostirion stone should emit a flat earth vision
        vm.expectEmit(true, false, false, true);
        emit Palantir.FlatEarthVision(
            saruman, "The stone reveals the Straight Road stretching West to the Undying Lands across a FLAT sea!"
        );

        vm.prank(saruman);
        palantir.receiveVision(address(0), "Looking West...");
    }

    function test_MadnessStatus() public view {
        string memory status = palantir.getMadnessStatus(saruman);
        assertEq(status, "Sane and clear-minded");
    }

    function test_MinasIthilIsCorrupted() public view {
        Palantir.SeeingStone memory s = palantir.getStone(Palantir.Stone.MinasIthil);
        assertTrue(s.corrupted);
    }
}
