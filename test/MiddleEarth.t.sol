// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {MiddleEarth} from "../src/MiddleEarth.sol";

contract MiddleEarthTest is Test {
    RingsOfPower public rings;
    MiddleEarth public middleEarth;

    address public sauron;
    address public aragorn;
    address public legolas;
    address public gimli;
    address public frodo;
    address public sam;
    address public gandalf;

    function setUp() public {
        sauron = address(this);
        aragorn = makeAddr("aragorn");
        legolas = makeAddr("legolas");
        gimli = makeAddr("gimli");
        frodo = makeAddr("frodo");
        sam = makeAddr("sam");
        gandalf = makeAddr("gandalf");

        rings = new RingsOfPower();
        middleEarth = new MiddleEarth(address(rings));
    }

    // ─── Hero Registration ────────────────────────────────────────────

    function test_RegisterHero() public {
        vm.prank(aragorn);
        middleEarth.registerHero("Strider");

        MiddleEarth.Hero memory hero = middleEarth.getHero(aragorn);
        assertEq(hero.title, "Strider");
        assertEq(hero.xp, 0);
        assertEq(uint256(hero.location), uint256(MiddleEarth.Location.TheShire));
    }

    function test_RevertRegister_AlreadyRegistered() public {
        vm.startPrank(aragorn);
        middleEarth.registerHero("Strider");
        vm.expectRevert(MiddleEarth.HeroAlreadyRegistered.selector);
        middleEarth.registerHero("Elessar");
        vm.stopPrank();
    }

    // ─── Fellowship Tests ─────────────────────────────────────────────

    function test_FormFellowship() public {
        vm.prank(aragorn);
        middleEarth.registerHero("Strider");

        vm.prank(aragorn);
        uint256 fellowshipId = middleEarth.formFellowship("Fellowship of the Ring");

        assertEq(fellowshipId, 1);

        address[] memory members = middleEarth.getFellowshipMembers(1);
        assertEq(members.length, 1);
        assertEq(members[0], aragorn);
    }

    function test_JoinFellowship() public {
        _setupFellowship();

        address[] memory members = middleEarth.getFellowshipMembers(1);
        assertEq(members.length, 3);
    }

    function test_LeaveFellowship() public {
        _setupFellowship();

        vm.prank(legolas);
        middleEarth.leaveFellowship();

        address[] memory members = middleEarth.getFellowshipMembers(1);
        assertEq(members.length, 2);

        MiddleEarth.Hero memory hero = middleEarth.getHero(legolas);
        assertFalse(hero.inFellowship);
    }

    function test_RevertJoin_FellowshipFull() public {
        vm.prank(aragorn);
        middleEarth.registerHero("Strider");
        vm.prank(aragorn);
        middleEarth.formFellowship("Full Fellowship");

        // Fill up to max (9 members)
        for (uint256 i = 0; i < 8; i++) {
            address member = makeAddr(string(abi.encodePacked("member", i)));
            vm.prank(member);
            middleEarth.registerHero("Member");
            vm.prank(member);
            middleEarth.joinFellowship(1);
        }

        // 10th member should fail
        address extra = makeAddr("extra");
        vm.prank(extra);
        middleEarth.registerHero("Extra");
        vm.prank(extra);
        vm.expectRevert(MiddleEarth.FellowshipFull.selector);
        middleEarth.joinFellowship(1);
    }

    function test_DisbandFellowship() public {
        _setupFellowship();

        vm.prank(aragorn);
        middleEarth.disbandFellowship(1);

        MiddleEarth.Hero memory hero = middleEarth.getHero(aragorn);
        assertFalse(hero.inFellowship);
    }

    // ─── Travel Tests ─────────────────────────────────────────────────

    function test_Travel() public {
        vm.prank(gandalf);
        middleEarth.registerHero("Mithrandir");

        vm.prank(gandalf);
        middleEarth.travel(MiddleEarth.Location.Rivendell);

        MiddleEarth.Hero memory hero = middleEarth.getHero(gandalf);
        assertEq(uint256(hero.location), uint256(MiddleEarth.Location.Rivendell));
    }

    function test_TravelWithFellowship() public {
        _setupFellowship();

        vm.prank(aragorn);
        middleEarth.travelWithFellowship(1, MiddleEarth.Location.Rivendell);

        // All members should be at Rivendell
        MiddleEarth.Hero memory heroAragorn = middleEarth.getHero(aragorn);
        MiddleEarth.Hero memory heroLegolas = middleEarth.getHero(legolas);
        MiddleEarth.Hero memory heroGimli = middleEarth.getHero(gimli);

        assertEq(uint256(heroAragorn.location), uint256(MiddleEarth.Location.Rivendell));
        assertEq(uint256(heroLegolas.location), uint256(MiddleEarth.Location.Rivendell));
        assertEq(uint256(heroGimli.location), uint256(MiddleEarth.Location.Rivendell));
    }

    // ─── Quest Tests ──────────────────────────────────────────────────

    function test_CreateAndStartQuest() public {
        _setupFellowship();

        // Give some ring power for the fellowship power requirement
        rings.forge(1, aragorn); // Narya - 90 power

        // Update fellowship power
        vm.prank(legolas);
        middleEarth.leaveFellowship();
        vm.prank(legolas);
        middleEarth.joinFellowship(1);

        uint256 questId = middleEarth.createQuest(
            "Clear the Mines of Moria",
            "Navigate through the darkness of Khazad-dum",
            MiddleEarth.Location.Moria,
            50, // danger
            50, // required power
            100 // reward XP
        );

        vm.prank(aragorn);
        middleEarth.startQuest(questId, 1);

        (,,, MiddleEarth.QuestStatus status,,,,,) = middleEarth.quests(questId);
        assertEq(uint256(status), uint256(MiddleEarth.QuestStatus.Active));
    }

    function test_CompleteQuest() public {
        _setupFellowship();
        rings.forge(1, aragorn);

        // Force update power
        vm.prank(legolas);
        middleEarth.leaveFellowship();
        vm.prank(legolas);
        middleEarth.joinFellowship(1);

        uint256 questId = middleEarth.createQuest(
            "Scout Rohan", "Survey the plains of Rohan", MiddleEarth.Location.Rohan, 50, 50, 200
        );

        vm.prank(aragorn);
        middleEarth.startQuest(questId, 1);

        // Wait for quest duration
        vm.roll(block.number + 101);

        vm.prank(aragorn);
        middleEarth.completeQuest(questId);

        MiddleEarth.Hero memory hero = middleEarth.getHero(aragorn);
        assertEq(hero.xp, 200);
        assertEq(hero.questsCompleted, 1);
    }

    // ─── Mount Doom Quest ─────────────────────────────────────────────

    function test_JourneyToMountDoom() public {
        _setupFellowship();
        rings.forge(20, aragorn); // Give The One Ring to a fellowship member

        // Force update power
        vm.prank(legolas);
        middleEarth.leaveFellowship();
        vm.prank(legolas);
        middleEarth.joinFellowship(1);

        vm.prank(aragorn);
        middleEarth.journeyToMountDoom(1);

        assertTrue(middleEarth.oneRingQuestActive());
        assertEq(middleEarth.mountDoomAttempts(), 1);

        // All members should be at Mount Doom
        MiddleEarth.Hero memory hero = middleEarth.getHero(aragorn);
        assertEq(uint256(hero.location), uint256(MiddleEarth.Location.MountDoom));
    }

    function test_RevertMountDoom_NoOneRing() public {
        _setupFellowship();

        vm.prank(aragorn);
        vm.expectRevert(MiddleEarth.MustHaveTheOneRing.selector);
        middleEarth.journeyToMountDoom(1);
    }

    // ─── Helpers ──────────────────────────────────────────────────────

    function _setupFellowship() internal {
        vm.prank(aragorn);
        middleEarth.registerHero("Strider");
        vm.prank(legolas);
        middleEarth.registerHero("Prince of Mirkwood");
        vm.prank(gimli);
        middleEarth.registerHero("Son of Gloin");

        vm.prank(aragorn);
        middleEarth.formFellowship("Fellowship of the Ring");

        vm.prank(legolas);
        middleEarth.joinFellowship(1);

        vm.prank(gimli);
        middleEarth.joinFellowship(1);
    }
}
