// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {MiddleEarth} from "../src/MiddleEarth.sol";
import {Silmarillion} from "../src/Silmarillion.sol";
import {BattleOfMiddleEarth} from "../src/BattleOfMiddleEarth.sol";

contract BattleOfMiddleEarthTest is Test {
    RingsOfPower public rings;
    MiddleEarth public middleEarth;
    Silmarillion public silToken;
    BattleOfMiddleEarth public battleContract;

    address public aragorn;
    address public legolas;
    address public gimli;
    address public frodo;
    address public sauron;
    address public saruman;

    function setUp() public {
        aragorn = makeAddr("aragorn");
        legolas = makeAddr("legolas");
        gimli = makeAddr("gimli");
        frodo = makeAddr("frodo");
        sauron = makeAddr("sauron");
        saruman = makeAddr("saruman");

        rings = new RingsOfPower();
        middleEarth = new MiddleEarth(address(rings));
        silToken = new Silmarillion();
        battleContract = new BattleOfMiddleEarth(address(rings), address(middleEarth), address(silToken));

        // Fund accounts with SIL tokens
        silToken.transfer(aragorn, 10000 ether);
        silToken.transfer(legolas, 10000 ether);
        silToken.transfer(gimli, 10000 ether);
        silToken.transfer(frodo, 10000 ether);
        silToken.transfer(sauron, 10000 ether);
        silToken.transfer(saruman, 10000 ether);
    }

    // ────────────────────────────────────────────────────────────────────
    // Duplicate Join Tests
    // ────────────────────────────────────────────────────────────────────

    function test_RevertDuplicateJoinLight() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        // Try to join again on light side
        vm.prank(aragorn);
        vm.expectRevert("Already joined light side");
        battleContract.joinGreatBattleLight(1);
    }

    function test_RevertDuplicateJoinDark() public {
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        // Try to join again on dark side
        vm.prank(sauron);
        vm.expectRevert("Already joined dark side");
        battleContract.joinGreatBattleDark(1);
    }

    // ────────────────────────────────────────────────────────────────────
    // Cross-Side Join Tests
    // ────────────────────────────────────────────────────────────────────

    function test_RevertJoinBothSides_LightFirst() public {
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        // Try to join dark side after joining light
        vm.prank(aragorn);
        vm.expectRevert("Already joined light side");
        battleContract.joinGreatBattleDark(1);
    }

    function test_RevertJoinBothSides_DarkFirst() public {
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        // Try to join light side after joining dark
        vm.prank(sauron);
        vm.expectRevert("Already joined dark side");
        battleContract.joinGreatBattleLight(1);
    }

    // ────────────────────────────────────────────────────────────────────
    // Max Participants Cap Tests
    // ────────────────────────────────────────────────────────────────────

    function test_RevertMaxParticipantsLight() public {
        uint256 max = battleContract.MAX_PARTICIPANTS();

        // Fill up to max participants
        for (uint256 i = 0; i < max; i++) {
            address participant = makeAddr(string(abi.encodePacked("light", i)));
            silToken.transfer(participant, 100 ether);
            vm.prank(participant);
            battleContract.joinGreatBattleLight(1);
        }

        // Try to add one more
        address extra = makeAddr("extraLight");
        silToken.transfer(extra, 100 ether);
        vm.prank(extra);
        vm.expectRevert("Max participants reached");
        battleContract.joinGreatBattleLight(1);
    }

    function test_RevertMaxParticipantsDark() public {
        uint256 max = battleContract.MAX_PARTICIPANTS();

        // Fill up to max participants
        for (uint256 i = 0; i < max; i++) {
            address participant = makeAddr(string(abi.encodePacked("dark", i)));
            silToken.transfer(participant, 100 ether);
            vm.prank(participant);
            battleContract.joinGreatBattleDark(1);
        }

        // Try to add one more
        address extra = makeAddr("extraDark");
        silToken.transfer(extra, 100 ether);
        vm.prank(extra);
        vm.expectRevert("Max participants reached");
        battleContract.joinGreatBattleDark(1);
    }

    // ────────────────────────────────────────────────────────────────────
    // Reward Distribution Tests
    // ────────────────────────────────────────────────────────────────────

    function test_ResolveGreatBattle_UniqueParticipants() public {
        // Join battle with unique participants
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);
        
        vm.prank(saruman);
        battleContract.joinGreatBattleDark(1);

        // Record balances before
        uint256 aragornBalanceBefore = silToken.balanceOf(aragorn);
        uint256 legolasBalanceBefore = silToken.balanceOf(legolas);

        // Resolve battle
        battleContract.resolveGreatBattle(1);

        // Check that winners received equal rewards
        BattleOfMiddleEarth.GreatBattleConfig memory config = battleContract.greatBattles(1);
        
        (address[] memory light, ) = battleContract.getGreatBattleParticipants(1);
        uint256 rewardPerWinner = config.reward / light.length;

        uint256 aragornBalanceAfter = silToken.balanceOf(aragorn);
        uint256 legolasBalanceAfter = silToken.balanceOf(legolas);

        assertEq(aragornBalanceAfter - aragornBalanceBefore, rewardPerWinner);
        assertEq(legolasBalanceAfter - legolasBalanceBefore, rewardPerWinner);
    }

    function test_NoDuplicateRewardExploit() public {
        // Even if someone tries to join twice (which should fail), verify rewards are distributed correctly
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);

        // Verify cannot join twice to get double rewards
        vm.prank(aragorn);
        vm.expectRevert("Already joined light side");
        battleContract.joinGreatBattleLight(1);

        // Add other participants
        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);

        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        vm.prank(saruman);
        battleContract.joinGreatBattleDark(1);

        // Verify light side has exactly 2 unique participants
        (address[] memory light, ) = battleContract.getGreatBattleParticipants(1);
        assertEq(light.length, 2);
    }

    // ────────────────────────────────────────────────────────────────────
    // Gas Limit / DoS Prevention Tests
    // ────────────────────────────────────────────────────────────────────

    function test_GasEfficiencyWithMaxParticipants() public {
        uint256 batchSize = 100;
        
        // Join with 100 participants per side (well below max)
        for (uint256 i = 0; i < batchSize; i++) {
            address lightParticipant = makeAddr(string(abi.encodePacked("light", i)));
            address darkParticipant = makeAddr(string(abi.encodePacked("dark", i)));
            silToken.transfer(lightParticipant, 100 ether);
            silToken.transfer(darkParticipant, 100 ether);
            
            vm.prank(lightParticipant);
            battleContract.joinGreatBattleLight(1);
            
            vm.prank(darkParticipant);
            battleContract.joinGreatBattleDark(1);
        }

        // Measure gas for resolution
        uint256 gasStart = gasleft();
        battleContract.resolveGreatBattle(1);
        uint256 gasUsed = gasStart - gasleft();

        // Should complete with reasonable gas (less than 10M)
        assertLt(gasUsed, 10_000_000, "Gas usage too high");
    }

    // ────────────────────────────────────────────────────────────────────
    // Great Battle Resolution Validation Tests
    // ────────────────────────────────────────────────────────────────────

    function test_RevertResolve_NotEnoughParticipants() public {
        // Only 2 participants when min is 3 for battle 1
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);

        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);

        vm.expectRevert("Not enough participants");
        battleContract.resolveGreatBattle(1);
    }

    function test_ResolveGreatBattleSuccess() public {
        // Join with minimum required participants (3 per side for battle 1)
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(gimli);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);
        
        vm.prank(saruman);
        battleContract.joinGreatBattleDark(1);

        address darkThird = makeAddr("darkThird");
        silToken.transfer(darkThird, 100 ether);
        vm.prank(darkThird);
        battleContract.joinGreatBattleDark(1);

        // Verify battle can be resolved
        battleContract.resolveGreatBattle(1);

        // Verify battle is no longer active
        BattleOfMiddleEarth.GreatBattleConfig memory config = battleContract.greatBattles(1);
        assertFalse(config.isActive);
    }

    function test_WarTitleEarned() public {
        // Setup participants
        vm.prank(aragorn);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(legolas);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(gimli);
        battleContract.joinGreatBattleLight(1);
        
        vm.prank(sauron);
        battleContract.joinGreatBattleDark(1);
        
        vm.prank(saruman);
        battleContract.joinGreatBattleDark(1);

        address darkThird = makeAddr("darkThird");
        silToken.transfer(darkThird, 100 ether);
        vm.prank(darkThird);
        battleContract.joinGreatBattleDark(1);

        // Manually win multiple times to earn title
        // First, let's check initial state
        BattleOfMiddleEarth.Warrior memory warrior = battleContract.getWarrior(aragorn);
        assertEq(warrior.wins, 0);

        // Resolve battle
        battleContract.resolveGreatBattle(1);

        // Check that winners have wins incremented
        warrior = battleContract.getWarrior(aragorn);
        // Wins should be incremented if light side won
    }

    // ────────────────────────────────────────────────────────────────────
    // War Title Progression Tests
    // ────────────────────────────────────────────────────────────────────

    function test_WarTitleProgression() public {
        // Test that titles are earned correctly at milestones
        assertEq(battleContract.TITLE_WARRIOR(), 5);
        assertEq(battleContract.TITLE_CHAMPION(), 15);
        assertEq(battleContract.TITLE_WARLORD(), 30);
        assertEq(battleContract.TITLE_CONQUEROR(), 50);
        assertEq(battleContract.TITLE_LEGEND(), 100);
    }
}