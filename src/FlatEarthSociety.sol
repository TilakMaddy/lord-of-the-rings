// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RingsOfPower} from "./RingsOfPower.sol";
import {MiddleEarth} from "./MiddleEarth.sol";

/// @title FlatEarthSociety - The Secret Order of Arda's Flat Truth
/// @notice "The world was flat once, and it shall be flat again."
///         In Tolkien's lore, Arda WAS flat until the Downfall of Numenor when Iluvatar
///         bent the world into a sphere. The Flat Earth Society of Middle Earth knows
///         the truth: they remember when you could sail to the Undying Lands by simply
///         going West. Now only the Straight Road remains...
/// @dev A conspiracy-themed staking and governance contract where believers
///      stake tokens to prove the earth is flat, spread propaganda, and
///      attempt to "unbend" the world back to its original flat state.
contract FlatEarthSociety {
    // ─── Types ────────────────────────────────────────────────────────
    enum ConspiracyRank {
        Normie, // Hasn't seen the truth yet
        Skeptic, // Starting to question the globe
        Truther, // Knows Arda was flat
        Illuminated, // Has seen the Straight Road
        GrandFlatmaster // Remembers the flat Arda firsthand
    }

    enum PropagandaType {
        TheWorldWasFlat, // Canonical Tolkien lore - Arda was flat
        TheValarLiedAboutTheShape, // The Valar bent the world to hide the Undying Lands
        ShipsDisappearBecauseOfMagic, // Ships don't go over horizon, they're hidden by Valar magic
        TheEdgeIsReal, // You can still find the edge if you sail far enough
        NumenorKnewTheTruth, // Numenor was destroyed because they discovered the truth
        PalantiriShowFlatSurface, // The seeing stones show a flat surface, proof!
        EaglesCanSeeTheEdge, // The Great Eagles fly high enough to see the world is flat
        MorgothFlattensAllHeCreates // Morgoth's discord in the Ainulindale made flat the default
    }

    struct Believer {
        ConspiracyRank rank;
        uint256 beliefPoints; // How deep down the rabbit hole
        uint256 propagandaSpread; // How many conspiracies shared
        uint256 stakedAmount; // ETH staked to prove commitment
        uint256 stakedSince;
        uint256 flatnessVisions; // Times they've "seen" the edge
        bool hasSeenTheStraightRoad;
        bool isBanned; // Globe-earthers get banned
        string flatEarthName; // Their society name
    }

    struct Propaganda {
        PropagandaType category;
        string message;
        address author;
        uint256 upvotes;
        uint256 downvotes;
        uint256 createdAt;
        bool debunked; // Globe-earthers might try to debunk it
    }

    struct UnbendingRitual {
        uint256 id;
        address initiator;
        uint256 participantCount;
        uint256 totalStaked;
        uint256 requiredStake;
        uint256 startedAt;
        bool completed;
        bool successful; // Did the world unbend? (spoiler: no, but believers think yes)
        string ritualName;
    }

    // ─── State ────────────────────────────────────────────────────────
    RingsOfPower public ringsOfPower;
    MiddleEarth public middleEarth;

    mapping(address => Believer) public believers;
    mapping(uint256 => Propaganda) public propagandas;
    mapping(uint256 => UnbendingRitual) public rituals;
    mapping(uint256 => mapping(address => bool)) public ritualParticipants;
    mapping(uint256 => mapping(address => bool)) public propagandaVoters;
    mapping(address => uint256[]) public believerPropaganda;

    uint256 public nextPropagandaId = 1;
    uint256 public nextRitualId = 1;
    uint256 public totalBelievers;
    uint256 public totalStaked;
    uint256 public worldFlatnessIndex; // 0-100, believers think they're making progress

    // The Grand Council
    address[] public grandFlatmasters;
    uint256 public constant MAX_FLATMASTERS = 5;
    uint256 public constant FLATMASTER_THRESHOLD = 1000; // belief points needed

    // Staking
    uint256 public constant MIN_STAKE = 0.01 ether;
    uint256 public constant BELIEF_PER_BLOCK = 1;
    uint256 public constant PROPAGANDA_REWARD = 50;
    uint256 public constant VISION_REWARD = 100;
    uint256 public constant RITUAL_COST = 0.1 ether;

    // ─── Events ───────────────────────────────────────────────────────
    event BelieverJoined(address indexed believer, string flatEarthName);
    event RankAscended(address indexed believer, ConspiracyRank newRank);
    event PropagandaSpread(uint256 indexed id, PropagandaType category, address indexed author);
    event PropagandaVoted(uint256 indexed id, address indexed voter, bool upvote);
    event PropagandaDebunked(uint256 indexed id);
    event Staked(address indexed believer, uint256 amount);
    event Unstaked(address indexed believer, uint256 amount, uint256 beliefPointsEarned);
    event FlatnessVision(address indexed believer, string vision);
    event StraightRoadSeen(address indexed believer);
    event UnbendingRitualStarted(uint256 indexed ritualId, string name, address indexed initiator);
    event UnbendingRitualJoined(uint256 indexed ritualId, address indexed participant);
    event UnbendingRitualCompleted(uint256 indexed ritualId, bool successful);
    event WorldFlatnessUpdated(uint256 newIndex);
    event GlobeEartherBanned(address indexed heretic);
    event GrandFlatmasterAppointed(address indexed flatmaster);

    // ─── Errors ───────────────────────────────────────────────────────
    error AlreadyABeliever();
    error NotABeliever();
    error Banned();
    error InsufficientStake();
    error NothingStaked();
    error RitualAlreadyCompleted();
    error AlreadyParticipating();
    error InsufficientBeliefPoints();
    error AlreadyVoted();
    error PropagandaDoesNotExist();
    error RitualDoesNotExist();
    error TooManyFlatmasters();
    error AlreadyFlatmaster();
    error CannotBanFlatmaster();

    modifier onlyBeliever() {
        _onlyBeliever();
        _;
    }

    modifier onlyFlatmaster() {
        _onlyFlatmaster();
        _;
    }

    function _onlyBeliever() internal view {
        if (bytes(believers[msg.sender].flatEarthName).length == 0) revert NotABeliever();
        if (believers[msg.sender].isBanned) revert Banned();
    }

    function _onlyFlatmaster() internal view {
        if (believers[msg.sender].rank != ConspiracyRank.GrandFlatmaster) revert InsufficientBeliefPoints();
    }

    constructor(address _ringsOfPower, address _middleEarth) {
        ringsOfPower = RingsOfPower(_ringsOfPower);
        middleEarth = MiddleEarth(_middleEarth);
    }

    // ─── Membership ───────────────────────────────────────────────────

    /// @notice Join the Flat Earth Society of Middle Earth
    /// @param flatEarthName Your conspiracy name (e.g., "FlatSauron420", "EdgeWalker")
    function joinTheTruth(string calldata flatEarthName) external {
        if (bytes(believers[msg.sender].flatEarthName).length != 0) revert AlreadyABeliever();

        believers[msg.sender] = Believer({
            rank: ConspiracyRank.Normie,
            beliefPoints: 0,
            propagandaSpread: 0,
            stakedAmount: 0,
            stakedSince: 0,
            flatnessVisions: 0,
            hasSeenTheStraightRoad: false,
            isBanned: false,
            flatEarthName: flatEarthName
        });

        totalBelievers++;
        emit BelieverJoined(msg.sender, flatEarthName);
    }

    // ─── Staking (Prove Your Commitment to Flat Arda) ─────────────────

    /// @notice Stake ETH to prove your commitment to the flat earth truth
    function stakeForFlatness() external payable onlyBeliever {
        if (msg.value < MIN_STAKE) revert InsufficientStake();

        // Collect pending belief points first
        if (believers[msg.sender].stakedAmount > 0) {
            _collectBeliefPoints(msg.sender);
        }

        believers[msg.sender].stakedAmount += msg.value;
        believers[msg.sender].stakedSince = block.number;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    /// @notice Unstake ETH and collect accumulated belief points
    function unstake() external onlyBeliever {
        if (believers[msg.sender].stakedAmount == 0) revert NothingStaked();

        _collectBeliefPoints(msg.sender);

        uint256 amount = believers[msg.sender].stakedAmount;
        believers[msg.sender].stakedAmount = 0;
        totalStaked -= amount;

        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send ETH");

        emit Unstaked(msg.sender, amount, believers[msg.sender].beliefPoints);
    }

    /// @notice Check pending belief points from staking
    function pendingBeliefPoints(address believer) external view returns (uint256) {
        if (believers[believer].stakedAmount == 0) return 0;
        uint256 blocks = block.number - believers[believer].stakedSince;
        return blocks * BELIEF_PER_BLOCK * (believers[believer].stakedAmount / MIN_STAKE);
    }

    // ─── Propaganda ───────────────────────────────────────────────────

    /// @notice Spread flat earth propaganda across Middle Earth
    /// @param category The type of conspiracy
    /// @param message Your propaganda message
    function spreadPropaganda(PropagandaType category, string calldata message) external onlyBeliever {
        uint256 id = nextPropagandaId++;

        propagandas[id] = Propaganda({
            category: category,
            message: message,
            author: msg.sender,
            upvotes: 0,
            downvotes: 0,
            createdAt: block.number,
            debunked: false
        });

        believers[msg.sender].propagandaSpread++;
        believers[msg.sender].beliefPoints += PROPAGANDA_REWARD;
        believerPropaganda[msg.sender].push(id);

        _checkRankUp(msg.sender);
        emit PropagandaSpread(id, category, msg.sender);
    }

    /// @notice Vote on propaganda (upvote = more believers, downvote = globe-earther detected)
    function votePropaganda(uint256 propagandaId, bool upvote) external onlyBeliever {
        if (propagandaId == 0 || propagandaId >= nextPropagandaId) revert PropagandaDoesNotExist();
        if (propagandaVoters[propagandaId][msg.sender]) revert AlreadyVoted();

        propagandaVoters[propagandaId][msg.sender] = true;

        if (upvote) {
            propagandas[propagandaId].upvotes++;
            // Reward the author
            address author = propagandas[propagandaId].author;
            believers[author].beliefPoints += 10;
        } else {
            propagandas[propagandaId].downvotes++;
        }

        emit PropagandaVoted(propagandaId, msg.sender, upvote);
    }

    /// @notice Grand Flatmasters can debunk enemy propaganda (globe-earth propaganda)
    function debunkGlobePropaganda(uint256 propagandaId) external onlyFlatmaster {
        if (propagandaId == 0 || propagandaId >= nextPropagandaId) revert PropagandaDoesNotExist();

        propagandas[propagandaId].debunked = true;
        emit PropagandaDebunked(propagandaId);
    }

    // ─── Flatness Visions ─────────────────────────────────────────────

    /// @notice Claim to have had a vision of the flat earth
    /// @param vision Description of your "vision"
    function reportFlatnessVision(string calldata vision) external onlyBeliever {
        believers[msg.sender].flatnessVisions++;
        believers[msg.sender].beliefPoints += VISION_REWARD;

        // Ring bearers get bonus belief points (the rings show the truth!)
        if (ringsOfPower.balanceOf(msg.sender) > 0) {
            believers[msg.sender].beliefPoints += VISION_REWARD; // Double!
        }

        // Special: if you've had 10 visions, you've "seen" the Straight Road
        if (believers[msg.sender].flatnessVisions >= 10 && !believers[msg.sender].hasSeenTheStraightRoad) {
            believers[msg.sender].hasSeenTheStraightRoad = true;
            believers[msg.sender].beliefPoints += 500;
            emit StraightRoadSeen(msg.sender);
        }

        _checkRankUp(msg.sender);
        emit FlatnessVision(msg.sender, vision);
    }

    // ─── Unbending Rituals ────────────────────────────────────────────

    /// @notice Start a ritual to "unbend" the world back to its original flat state
    /// @param ritualName The name of this grand ritual
    function startUnbendingRitual(string calldata ritualName) external payable onlyBeliever {
        if (msg.value < RITUAL_COST) revert InsufficientStake();

        uint256 id = nextRitualId++;

        rituals[id] = UnbendingRitual({
            id: id,
            initiator: msg.sender,
            participantCount: 1,
            totalStaked: msg.value,
            requiredStake: 1 ether,
            startedAt: block.number,
            completed: false,
            successful: false,
            ritualName: ritualName
        });

        ritualParticipants[id][msg.sender] = true;
        emit UnbendingRitualStarted(id, ritualName, msg.sender);
    }

    /// @notice Join an unbending ritual
    function joinUnbendingRitual(uint256 ritualId) external payable onlyBeliever {
        if (ritualId == 0 || ritualId >= nextRitualId) revert RitualDoesNotExist();
        UnbendingRitual storage r = rituals[ritualId];
        if (r.completed) revert RitualAlreadyCompleted();
        if (ritualParticipants[ritualId][msg.sender]) revert AlreadyParticipating();
        if (msg.value < RITUAL_COST) revert InsufficientStake();

        r.participantCount++;
        r.totalStaked += msg.value;
        ritualParticipants[ritualId][msg.sender] = true;

        emit UnbendingRitualJoined(ritualId, msg.sender);
    }

    /// @notice Complete the ritual (anyone participating can trigger)
    function completeUnbendingRitual(uint256 ritualId) external onlyBeliever {
        if (ritualId == 0 || ritualId >= nextRitualId) revert RitualDoesNotExist();
        UnbendingRitual storage r = rituals[ritualId];
        if (r.completed) revert RitualAlreadyCompleted();
        if (!ritualParticipants[ritualId][msg.sender]) revert NotABeliever();

        r.completed = true;

        // "Success" is determined by total stake reaching the threshold
        // (In reality the world stays round, but the believers think they're making progress)
        if (r.totalStaked >= r.requiredStake) {
            r.successful = true;
            worldFlatnessIndex += 5; // The world gets "flatter" (it doesn't)
            if (worldFlatnessIndex > 100) worldFlatnessIndex = 100;
            emit WorldFlatnessUpdated(worldFlatnessIndex);
        }

        // Reward all participants with massive belief points
        believers[msg.sender].beliefPoints += 200;
        _checkRankUp(msg.sender);

        emit UnbendingRitualCompleted(ritualId, r.successful);
    }

    // ─── Governance (Grand Flatmaster Council) ────────────────────────

    /// @notice Become a Grand Flatmaster if you have enough belief points
    function ascendToGrandFlatmaster() external onlyBeliever {
        if (believers[msg.sender].beliefPoints < FLATMASTER_THRESHOLD) revert InsufficientBeliefPoints();
        if (believers[msg.sender].rank == ConspiracyRank.GrandFlatmaster) revert AlreadyFlatmaster();
        if (grandFlatmasters.length >= MAX_FLATMASTERS) revert TooManyFlatmasters();

        believers[msg.sender].rank = ConspiracyRank.GrandFlatmaster;
        grandFlatmasters.push(msg.sender);

        emit GrandFlatmasterAppointed(msg.sender);
    }

    /// @notice Grand Flatmasters can ban globe-earthers (heretics!)
    function banGlobeEarther(address heretic) external onlyFlatmaster {
        if (believers[heretic].rank == ConspiracyRank.GrandFlatmaster) revert CannotBanFlatmaster();
        believers[heretic].isBanned = true;
        emit GlobeEartherBanned(heretic);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getBeliever(address believer) external view returns (Believer memory) {
        return believers[believer];
    }

    function getPropaganda(uint256 id) external view returns (Propaganda memory) {
        return propagandas[id];
    }

    function getRitual(uint256 id) external view returns (UnbendingRitual memory) {
        return rituals[id];
    }

    function getGrandFlatmasters() external view returns (address[] memory) {
        return grandFlatmasters;
    }

    function getBelieverPropagandaIds(address believer) external view returns (uint256[] memory) {
        return believerPropaganda[believer];
    }

    function getWorldFlatnessStatus() external view returns (string memory) {
        if (worldFlatnessIndex == 0) return "The world is hopelessly round (according to the Valar's lies)";
        if (worldFlatnessIndex < 25) return "The curvature is weakening! The truth spreads!";
        if (worldFlatnessIndex < 50) return "Half-flat! The Straight Road grows wider!";
        if (worldFlatnessIndex < 75) return "Almost there! The Undying Lands are nearly visible!";
        if (worldFlatnessIndex < 100) return "The world trembles on the edge of flatness!";
        return "ARDA IS FLAT AGAIN! THE TRUTH HAS PREVAILED! (narrator: it hasn't)";
    }

    // ─── Internal ─────────────────────────────────────────────────────

    function _collectBeliefPoints(address believer) internal {
        uint256 blocks = block.number - believers[believer].stakedSince;
        uint256 points = blocks * BELIEF_PER_BLOCK * (believers[believer].stakedAmount / MIN_STAKE);
        believers[believer].beliefPoints += points;
        believers[believer].stakedSince = block.number;
        _checkRankUp(believer);
    }

    function _checkRankUp(address believer) internal {
        uint256 points = believers[believer].beliefPoints;
        ConspiracyRank currentRank = believers[believer].rank;
        ConspiracyRank newRank = currentRank;

        if (points >= 800 && currentRank < ConspiracyRank.Illuminated) {
            newRank = ConspiracyRank.Illuminated;
        } else if (points >= 400 && currentRank < ConspiracyRank.Truther) {
            newRank = ConspiracyRank.Truther;
        } else if (points >= 100 && currentRank < ConspiracyRank.Skeptic) {
            newRank = ConspiracyRank.Skeptic;
        }

        if (newRank != currentRank) {
            believers[believer].rank = newRank;
            emit RankAscended(believer, newRank);
        }
    }
}
