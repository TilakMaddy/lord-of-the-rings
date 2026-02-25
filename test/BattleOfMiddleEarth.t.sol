// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BattleOfMiddleEarth} from "../src/BattleOfMiddleEarth.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {MiddleEarth} from "../src/MiddleEarth.sol";
import {Silmarillion} from "../src/Silmarillion.sol";

contract BattleOfMiddleEarthTest is Test {
    BattleOfMiddleEarth public battleContract;
    RingsOfPower public rings;
    MiddleEarth public middleEarth;
    Silmarillion public sil;

    address public aragorn;
    address public legolas;
    address public gimli;
    address public gandalf;
    address public sauron;
    address public saruman;
    address public witchKing;

    function setUp() public {
        aragorn = makeAddr("aragorn");
        legolas = makeAddr("legolas");
        gimli = makeAddr("gimli");
        gandalf = makeAddr("gandalf");
        sauron = makeAddr("sauron");
        saruman = makeAddr("saruman");
        witchKing = makeAddr("witchKing");

        sil = new Silmarillion();
        rings = new RingsOfPower();
        middleEarth = new MiddleEarth(address(rings));
        battleContract = new BattleOfMiddleEarth(address(rings), address(middleEarth), address(sil));

        // Fund users with SIL for testing
        deal(address(sil), aragorn, 10000 ether);
        deal(address(sil), legolas, 10000 ether);
        deal(address(sil), gimli, 10000 ether);
        deal(address(sil), gandalf, 10000 ether);
        deal(address(sil), sauron, 10000 ether);
        deal(address(sil), saruman, 10000 ether);
        deal(address(sil), witchKing, 10000 ether);
    }

    // ─── Duplicate Join Prevention Tests ──────────────────────────────

    function test_CannotJoinLightSideTwice() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        vm.expectRevert("Already joined light side");
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
    }

    function test_CannotJoinDarkSideTwice() public {
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        vm.expectRevert("Already joined dark side");
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);
    }

    function test_CanJoinDifferentSidesInDifferentBattles() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        vm.prank(aragorn);
        battleContract.joinGreatBattleDark(2);

        (address[] memory lightSide1, address[] memory darkSide1) = battleContract.getGreatBattleParticipants(1);
        (address[] memory lightSide2, address[] memory darkSide2) = battleContract.getGreatBattleParticipants(2);

        assertEq(lightSide1.length, 1);
        assertEq(darkSide1.length, 0);
        assertEq(lightSide2.length, 0);
        assertEq(darkSide2.length, 1);
    }

    function test_MultipleUsersCanJoinLightSide() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);

        vm.prank(gimli);
        battleContract.joinGreatBattleLight(1);

        (address[] memory lightSide, address[] memory darkSide) = battleContract.getGreatBattleParticipants(1);
        assertEq(lightSide.length, 3);
        assertEq(darkSide.length, 0);
    }

    function test_MultipleUsersCanJoinDarkSide() public {
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        vm.prank(saruman);
        battleContract.joinGreatBattleDark(1);

        vm.prank(witchKing);
        battleContract.joinGreatBattleDark(1);

        (address[] memory lightSide, address[] memory darkSide) = battleContract.getGreatBattleParticipants(1);
        assertEq(lightSide.length, 0);
        assertEq(darkSide.length, 3);
    }

    // ─── Maximum Participant Limit Tests ─────────────────────────────

    function test_CannotJoinLightSideWhenMaxReached() public {
        // Add max participants to light side
        for (uint256 i = 0; i < 100; i++) {
            address participant = makeAddr(string(abi.encodePacked("light", i)));
            vm.prank(participant);
            battleContract.joinGreatBattleLight(1);
        }

        // 101st participant should fail
        address extra = makeAddr("extra");
        vm.expectRevert("Max participants reached");
        vm.prank(extra);
        battleContract.joinGreatBattleLight(1);
    }

    function test_CannotJoinDarkSideWhenMaxReached() public {
        // Add max participants to dark side
        for (uint256 i = 0; i < 100; i++) {
            address participant = makeAddr(string(abi.encodePacked("dark", i)));
            vm.prank(participant);
            battleContract.joinGreatBattleDark(1);
        }

        // 101st participant should fail
        address extra = makeAddr("extra");
        vm.expectRevert("Max participants reached");
        vm.prank(extra);
        battleContract.joinGreatBattleDark(1);
    }

    function test_MaxParticipantsIndependentlyTracked() public {
        // Fill light side to max
        for (uint256 i = 0; i < 100; i++) {
            address participant = makeAddr(string(abi.encodePacked("light", i)));
            vm.prank(participant);
            battleContract.joinGreatBattleLight(1);
        }

        // Dark side should still be able to join
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        (address[] memory lightSide, address[] memory darkSide) = battleContract.getGreatBattleParticipants(1);
        assertEq(lightSide.length, 100);
        assertEq(darkSide.length, 1);
    }

    // ─── Normal Join Functionality Tests ──────────────────────────────

    function test_NormalJoinLightSideWorks() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        (address[] memory lightSide, address[] memory darkSide) = battleContract.getGreatBattleParticipants(1);
        assertEq(lightSide.length, 1);
        assertEq(lightSide[0], aragorn);
        assertEq(darkSide.length, 0);
    }

    function test_NormalJoinDarkSideWorks() public {
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        (address[] memory lightSide, address[] memory darkSide) = battleContract.getGreatBattleParticipants(1);
        assertEq(lightSide.length, 0);
        assertEq(darkSide.length, 1);
        assertEq(darkSide[0], sauron);
    }

    function test_CannotJoinInactiveBattleLightSide() public {
        // Battle 6 doesn't exist (nextGreatBattleId starts at 6 after initialization)
        vm.expectRevert("Battle not active");
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(999);
    }

    function test_CannotJoinInactiveBattleDarkSide() public {
        vm.expectRevert("Battle not active");
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(999);
    }

    function test_JoinedStateTrackedCorrectly() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        assertTrue(battleContract.greatBattleJoinedLight(1, aragorn));
        assertFalse(battleContract.greatBattleJoinedDark(1, aragorn));

        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        assertTrue(battleContract.greatBattleJoinedDark(1, sauron));
        assertFalse(battleContract.greatBattleJoinedLight(1, sauron));
    }

    function test_EmitEventOnJoin() public {
        vm.expectEmit(true, true, true, false);
        emit BattleOfMiddleEarth.GreatBattleJoined(1, aragorn, true);
        
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
    }

    function test_MaxConstantIsCorrect() public {
        assertEq(battleContract.MAX_GREAT_BATTLE_PARTICIPANTS(), 100);
    }
}
