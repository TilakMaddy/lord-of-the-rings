// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RingsOfPower} from "./RingsOfPower.sol";

/// @title Palantir - The Seeing Stones of Middle Earth
/// @notice "The Stones are not all lost. The palantiri came from beyond Westernesse,
///          from Eldamar. The Noldor made them."
/// @dev Seven seeing stones that allow on-chain "scrying" - reading data about
///      other addresses, ring bearers, and (according to Flat Earth believers)
///      proving the world is flat because the stones show a flat surface.
contract Palantir {
    // ─── Types ────────────────────────────────────────────────────────
    enum Stone {
        OrthancsStone, // Saruman's stone
        MinasTirith, // Denethor's stone
        MinasIthil, // Captured by Sauron
        Osgiliath, // Lost in the river
        Annuminas, // Lost
        AmonSul, // Lost
        ElostirionStone // Looks only to the West (to the Undying Lands / edge of flat world)
    }

    struct SeeingStone {
        Stone stoneType;
        string name;
        address keeper;
        bool found; // Has it been discovered?
        bool corrupted; // Has Sauron's influence touched it?
        uint256 timesUsed;
        uint256 lastUsedAt;
    }

    struct Vision {
        address seer;
        address target;
        uint256 timestamp;
        string interpretation;
        bool madnessInduced; // Staring too long can drive you mad
    }

    struct ScryingSession {
        address seer;
        Stone stone;
        uint256 startBlock;
        bool active;
    }

    // ─── State ────────────────────────────────────────────────────────
    RingsOfPower public ringsOfPower;

    uint256 public constant NUM_STONES = 7;
    uint256 public constant SCRYING_COOLDOWN = 50; // blocks between uses
    uint256 public constant MADNESS_THRESHOLD = 10; // uses before risk of madness

    mapping(Stone => SeeingStone) public stones;
    mapping(address => ScryingSession) public activeSessions;
    mapping(address => uint256) public madnessLevel; // 0-100
    mapping(address => Vision[]) public visionHistory;
    mapping(address => mapping(Stone => uint256)) public stoneUsageCount;

    uint256 public totalVisions;
    uint256 public madnessInducedCount;

    // ─── Events ───────────────────────────────────────────────────────
    event StoneFound(Stone indexed stone, address indexed finder);
    event StoneCorrupted(Stone indexed stone);
    event ScryingStarted(address indexed seer, Stone indexed stone);
    event VisionReceived(address indexed seer, address indexed target, string interpretation);
    event MadnessInduced(address indexed seer, uint256 madnessLevel);
    event StoneTransferred(Stone indexed stone, address indexed from, address indexed to);
    event FlatEarthVision(address indexed seer, string proof);

    // ─── Errors ───────────────────────────────────────────────────────
    error StoneAlreadyFound();
    error StoneNotFound();
    error NotStoneKeeper();
    error ScryingOnCooldown();
    error AlreadyScrying();
    error NotScrying();
    error TooMad();
    error InvalidStone();

    constructor(address _ringsOfPower) {
        ringsOfPower = RingsOfPower(_ringsOfPower);
        _initializeStones();
    }

    function _initializeStones() internal {
        stones[Stone.OrthancsStone] = SeeingStone({
            stoneType: Stone.OrthancsStone,
            name: "Stone of Orthanc",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
        stones[Stone.MinasTirith] = SeeingStone({
            stoneType: Stone.MinasTirith,
            name: "Stone of Minas Tirith",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
        stones[Stone.MinasIthil] = SeeingStone({
            stoneType: Stone.MinasIthil,
            name: "Stone of Minas Ithil",
            keeper: address(0),
            found: false,
            corrupted: true,
            timesUsed: 0,
            lastUsedAt: 0 // Already corrupted by Sauron
        });
        stones[Stone.Osgiliath] = SeeingStone({
            stoneType: Stone.Osgiliath,
            name: "Stone of Osgiliath",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
        stones[Stone.Annuminas] = SeeingStone({
            stoneType: Stone.Annuminas,
            name: "Stone of Annuminas",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
        stones[Stone.AmonSul] = SeeingStone({
            stoneType: Stone.AmonSul,
            name: "Stone of Amon Sul",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
        stones[Stone.ElostirionStone] = SeeingStone({
            stoneType: Stone.ElostirionStone,
            name: "Stone of Elostirion",
            keeper: address(0),
            found: false,
            corrupted: false,
            timesUsed: 0,
            lastUsedAt: 0
        });
    }

    // ─── Discovery ────────────────────────────────────────────────────

    /// @notice Discover a lost Palantir. Only ring bearers or those with high XP can find them.
    /// @param stone Which stone to discover
    function discoverStone(Stone stone) external {
        SeeingStone storage s = stones[stone];
        if (s.found) revert StoneAlreadyFound();

        // Must be a ring bearer to discover a Palantir
        require(ringsOfPower.balanceOf(msg.sender) > 0, "Only ring bearers can find Palantiri");

        s.found = true;
        s.keeper = msg.sender;

        emit StoneFound(stone, msg.sender);
    }

    /// @notice Transfer a stone to another keeper
    function transferStone(Stone stone, address newKeeper) external {
        SeeingStone storage s = stones[stone];
        if (!s.found) revert StoneNotFound();
        if (s.keeper != msg.sender) revert NotStoneKeeper();

        address oldKeeper = s.keeper;
        s.keeper = newKeeper;

        emit StoneTransferred(stone, oldKeeper, newKeeper);
    }

    // ─── Scrying ──────────────────────────────────────────────────────

    /// @notice Begin a scrying session with a Palantir
    /// @param stone The stone to use
    function beginScrying(Stone stone) external {
        SeeingStone storage s = stones[stone];
        if (!s.found) revert StoneNotFound();
        if (s.keeper != msg.sender) revert NotStoneKeeper();
        if (activeSessions[msg.sender].active) revert AlreadyScrying();
        if (s.lastUsedAt + SCRYING_COOLDOWN > block.number) revert ScryingOnCooldown();
        if (madnessLevel[msg.sender] >= 100) revert TooMad();

        activeSessions[msg.sender] =
            ScryingSession({seer: msg.sender, stone: stone, startBlock: block.number, active: true});

        s.timesUsed++;
        s.lastUsedAt = block.number;
        stoneUsageCount[msg.sender][stone]++;

        emit ScryingStarted(msg.sender, stone);
    }

    /// @notice Receive a vision while scrying - target an address to learn about
    /// @param target The address to scry upon
    /// @param interpretation Your reading of the vision
    function receiveVision(address target, string calldata interpretation) external {
        if (!activeSessions[msg.sender].active) revert NotScrying();

        ScryingSession storage session = activeSessions[msg.sender];

        // Check for madness from overuse
        bool madnessInduced = false;
        Stone stone = session.stone;
        uint256 totalUses = stoneUsageCount[msg.sender][stone];

        if (totalUses > MADNESS_THRESHOLD) {
            // Pseudo-random madness check
            uint256 madnessRoll = uint256(keccak256(abi.encodePacked(block.number, msg.sender, totalUses))) % 100;
            if (madnessRoll < totalUses * 5) {
                madnessInduced = true;
                madnessLevel[msg.sender] += 10;
                if (stones[stone].corrupted) {
                    madnessLevel[msg.sender] += 20; // Corrupted stones are worse
                }
                madnessInducedCount++;
                emit MadnessInduced(msg.sender, madnessLevel[msg.sender]);
            }
        }

        // The Elostirion Stone always shows the "flat" western sea
        if (stone == Stone.ElostirionStone) {
            emit FlatEarthVision(
                msg.sender,
                "The stone reveals the Straight Road stretching West to the Undying Lands across a FLAT sea!"
            );
        }

        Vision memory v = Vision({
            seer: msg.sender,
            target: target,
            timestamp: block.timestamp,
            interpretation: interpretation,
            madnessInduced: madnessInduced
        });

        visionHistory[msg.sender].push(v);
        totalVisions++;

        // End the session
        session.active = false;

        emit VisionReceived(msg.sender, target, interpretation);
    }

    /// @notice Cancel an active scrying session
    function endScrying() external {
        if (!activeSessions[msg.sender].active) revert NotScrying();
        activeSessions[msg.sender].active = false;
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getStone(Stone stone) external view returns (SeeingStone memory) {
        return stones[stone];
    }

    function getVisionHistory(address seer) external view returns (Vision[] memory) {
        return visionHistory[seer];
    }

    function getVisionCount(address seer) external view returns (uint256) {
        return visionHistory[seer].length;
    }

    function getMadnessLevel(address seer) external view returns (uint256) {
        return madnessLevel[seer];
    }

    function isStoneAvailable(Stone stone) external view returns (bool) {
        SeeingStone storage s = stones[stone];
        return s.found && (s.lastUsedAt + SCRYING_COOLDOWN <= block.number);
    }

    function getMadnessStatus(address seer) external view returns (string memory) {
        uint256 level = madnessLevel[seer];
        if (level == 0) return "Sane and clear-minded";
        if (level < 25) return "Mildly unsettled by visions";
        if (level < 50) return "Hearing whispers from the stones";
        if (level < 75) return "The Eye of Sauron haunts your dreams";
        if (level < 100) return "Teetering on the edge of madness, like Denethor";
        return "Lost to madness. The stones have consumed your mind.";
    }
}
