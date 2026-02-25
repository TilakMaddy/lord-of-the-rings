// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {MiddleEarth} from "../src/MiddleEarth.sol";
import {FlatEarthSociety} from "../src/FlatEarthSociety.sol";

contract FlatEarthSocietyTest is Test {
    RingsOfPower public rings;
    MiddleEarth public middleEarth;
    FlatEarthSociety public flatEarth;

    address public sauron;
    address public flatSauron420;
    address public edgeWalker;
    address public globeEarther;

    function setUp() public {
        sauron = address(this);
        flatSauron420 = makeAddr("flatSauron420");
        edgeWalker = makeAddr("edgeWalker");
        globeEarther = makeAddr("globeEarther");

        rings = new RingsOfPower();
        middleEarth = new MiddleEarth(address(rings));
        flatEarth = new FlatEarthSociety(address(rings), address(middleEarth));

        // Fund believers
        vm.deal(flatSauron420, 10 ether);
        vm.deal(edgeWalker, 10 ether);
        vm.deal(globeEarther, 10 ether);
    }

    // ─── Membership Tests ─────────────────────────────────────────────

    function test_JoinTheTruth() public {
        vm.prank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(b.flatEarthName, "FlatSauron420");
        assertEq(uint256(b.rank), uint256(FlatEarthSociety.ConspiracyRank.Normie));
        assertEq(flatEarth.totalBelievers(), 1);
    }

    function test_RevertJoin_AlreadyMember() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");
        vm.expectRevert(FlatEarthSociety.AlreadyABeliever.selector);
        flatEarth.joinTheTruth("FlatSauron421");
        vm.stopPrank();
    }

    // ─── Staking Tests ────────────────────────────────────────────────

    function test_StakeForFlatness() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");
        flatEarth.stakeForFlatness{value: 1 ether}();

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(b.stakedAmount, 1 ether);
        assertEq(flatEarth.totalStaked(), 1 ether);
        vm.stopPrank();
    }

    function test_Unstake() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");
        flatEarth.stakeForFlatness{value: 1 ether}();

        vm.roll(block.number + 100);

        uint256 balanceBefore = flatSauron420.balance;
        flatEarth.unstake();
        uint256 balanceAfter = flatSauron420.balance;

        assertEq(balanceAfter - balanceBefore, 1 ether);
        vm.stopPrank();
    }

    function test_StakingEarnsBeliefPoints() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");
        flatEarth.stakeForFlatness{value: 0.1 ether}();

        vm.roll(block.number + 1000);

        uint256 pending = flatEarth.pendingBeliefPoints(flatSauron420);
        assertEq(pending, 10000); // 1000 blocks * 1 point/block * 10 units (0.1/0.01)
        vm.stopPrank();
    }

    // ─── Propaganda Tests ─────────────────────────────────────────────

    function test_SpreadPropaganda() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        flatEarth.spreadPropaganda(
            FlatEarthSociety.PropagandaType.TheWorldWasFlat,
            "Arda was flat before the Downfall of Numenor! This is CANON!"
        );

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(b.propagandaSpread, 1);
        assertEq(b.beliefPoints, 50); // PROPAGANDA_REWARD
        vm.stopPrank();
    }

    function test_VotePropaganda() public {
        vm.prank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        vm.prank(flatSauron420);
        flatEarth.spreadPropaganda(
            FlatEarthSociety.PropagandaType.NumenorKnewTheTruth,
            "Numenor was destroyed because they knew the earth was flat!"
        );

        vm.prank(edgeWalker);
        flatEarth.joinTheTruth("EdgeWalker");

        vm.prank(edgeWalker);
        flatEarth.votePropaganda(1, true);

        FlatEarthSociety.Propaganda memory p = flatEarth.getPropaganda(1);
        assertEq(p.upvotes, 1);
    }

    // ─── Flatness Visions ─────────────────────────────────────────────

    function test_ReportVision() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        flatEarth.reportFlatnessVision("I saw the edge! Ships fall off!");

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(b.flatnessVisions, 1);
        assertEq(b.beliefPoints, 100); // VISION_REWARD
        vm.stopPrank();
    }

    function test_SeeTheStraightRoad() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        // 10 visions to see the Straight Road
        for (uint256 i = 0; i < 10; i++) {
            flatEarth.reportFlatnessVision("Vision!");
        }

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertTrue(b.hasSeenTheStraightRoad);
        // 10 * 100 (visions) + 500 (straight road bonus) = 1500
        assertEq(b.beliefPoints, 1500);
        vm.stopPrank();
    }

    function test_RingBearerGetsDoubleVisionPoints() public {
        rings.forge(1, flatSauron420); // Give an elven ring

        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");
        flatEarth.reportFlatnessVision("The ring shows me the flat truth!");

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(b.beliefPoints, 200); // Double for ring bearer
        vm.stopPrank();
    }

    // ─── Unbending Ritual Tests ───────────────────────────────────────

    function test_StartAndJoinRitual() public {
        vm.prank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        vm.prank(flatSauron420);
        flatEarth.startUnbendingRitual{value: 0.5 ether}("The Great Unbending");

        FlatEarthSociety.UnbendingRitual memory r = flatEarth.getRitual(1);
        assertEq(r.participantCount, 1);
        assertEq(r.totalStaked, 0.5 ether);
        assertEq(r.ritualName, "The Great Unbending");

        // Another believer joins
        vm.prank(edgeWalker);
        flatEarth.joinTheTruth("EdgeWalker");

        vm.prank(edgeWalker);
        flatEarth.joinUnbendingRitual{value: 0.6 ether}(1);

        r = flatEarth.getRitual(1);
        assertEq(r.participantCount, 2);
        assertEq(r.totalStaked, 1.1 ether);
    }

    function test_CompleteSuccessfulRitual() public {
        vm.prank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        vm.prank(flatSauron420);
        flatEarth.startUnbendingRitual{value: 1 ether}("Flatten Arda");

        vm.prank(flatSauron420);
        flatEarth.completeUnbendingRitual(1);

        FlatEarthSociety.UnbendingRitual memory r = flatEarth.getRitual(1);
        assertTrue(r.completed);
        assertTrue(r.successful);
        assertEq(flatEarth.worldFlatnessIndex(), 5);
    }

    // ─── Rank System Tests ────────────────────────────────────────────

    function test_RankUpFromPropaganda() public {
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        // Spread enough propaganda to rank up to Skeptic (100 points)
        // Each propaganda gives 50 points, so 2 should do it
        flatEarth.spreadPropaganda(FlatEarthSociety.PropagandaType.TheWorldWasFlat, "Truth 1");
        flatEarth.spreadPropaganda(FlatEarthSociety.PropagandaType.TheEdgeIsReal, "Truth 2");

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(flatSauron420);
        assertEq(uint256(b.rank), uint256(FlatEarthSociety.ConspiracyRank.Skeptic));
        vm.stopPrank();
    }

    // ─── World Flatness Status ────────────────────────────────────────

    function test_WorldFlatnessStatus() public view {
        string memory status = flatEarth.getWorldFlatnessStatus();
        assertEq(status, "The world is hopelessly round (according to the Valar's lies)");
    }

    // ─── Ban System ───────────────────────────────────────────────────

    function test_BanGlobeEarther() public {
        // First create a Grand Flatmaster
        vm.startPrank(flatSauron420);
        flatEarth.joinTheTruth("FlatSauron420");

        // Get to 1000 belief points through visions (ring bearer gets 200/vision)
        vm.stopPrank();
        rings.forge(1, flatSauron420);

        vm.startPrank(flatSauron420);
        for (uint256 i = 0; i < 10; i++) {
            flatEarth.reportFlatnessVision("Vision!");
        }
        // Should have 2000 + 500 = 2500 points

        flatEarth.ascendToGrandFlatmaster();
        vm.stopPrank();

        // Register the globe earther
        vm.prank(globeEarther);
        flatEarth.joinTheTruth("DefinitelyNotAGlobeEarther");

        // Ban them!
        vm.prank(flatSauron420);
        flatEarth.banGlobeEarther(globeEarther);

        FlatEarthSociety.Believer memory b = flatEarth.getBeliever(globeEarther);
        assertTrue(b.isBanned);
    }
}
