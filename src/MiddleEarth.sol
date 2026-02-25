// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RingsOfPower} from "./RingsOfPower.sol";

/// @title MiddleEarth - Fellowship, Quests, and the Journey to Mount Doom
/// @notice "The world is changed. I feel it in the water. I feel it in the earth.
///          I smell it in the air. Much that once was is lost."
/// @dev Manage fellowships, embark on quests, and attempt to destroy The One Ring.
contract MiddleEarth {
    // ─── Types ────────────────────────────────────────────────────────
    enum QuestStatus {
        NotStarted,
        Active,
        Completed,
        Failed
    }
    enum Location {
        TheShire,
        Rivendell,
        Moria,
        Lothlorien,
        Rohan,
        Gondor,
        Mordor,
        MountDoom,
        TheUndyingLands, // Edge of the flat world
        TheVoid // Beyond the edge - where flat earth truth lives
    }

    struct Fellowship {
        string name;
        address leader;
        address[] members;
        bool active;
        uint256 formedAt;
        Location currentLocation;
        uint256 totalPower;
    }

    struct Quest {
        string name;
        string description;
        uint256 fellowshipId;
        QuestStatus status;
        Location destination;
        uint256 dangerLevel; // 1-100
        uint256 requiredPower;
        uint256 rewardXp;
        uint256 startedAt;
    }

    struct Hero {
        string title;
        uint256 xp;
        uint256 questsCompleted;
        uint256 questsFailed;
        Location location;
        bool inFellowship;
        uint256 fellowshipId;
    }

    // ─── State ────────────────────────────────────────────────────────
    RingsOfPower public ringsOfPower;

    uint256 public nextFellowshipId = 1;
    uint256 public nextQuestId = 1;

    uint256 public constant MAX_FELLOWSHIP_SIZE = 9; // The Fellowship of the Ring had 9
    uint256 public constant QUEST_DURATION_BLOCKS = 100;

    mapping(uint256 => Fellowship) public fellowships;
    mapping(uint256 => Quest) public quests;
    mapping(address => Hero) public heroes;
    mapping(uint256 => mapping(address => bool)) public fellowshipMembers;

    // Mount Doom tracking
    bool public oneRingQuestActive;
    uint256 public oneRingQuestFellowship;
    uint256 public mountDoomAttempts;

    // ─── Events ───────────────────────────────────────────────────────
    event HeroRegistered(address indexed hero, string title);
    event FellowshipFormed(uint256 indexed id, string name, address indexed leader);
    event MemberJoined(uint256 indexed fellowshipId, address indexed member);
    event MemberLeft(uint256 indexed fellowshipId, address indexed member);
    event FellowshipDisbanded(uint256 indexed fellowshipId);
    event QuestCreated(uint256 indexed questId, string name, Location destination);
    event QuestStarted(uint256 indexed questId, uint256 indexed fellowshipId);
    event QuestCompleted(uint256 indexed questId, uint256 xpReward);
    event QuestFailed(uint256 indexed questId);
    event HeroMoved(address indexed hero, Location from, Location to);
    event MountDoomAttempted(uint256 indexed fellowshipId, bool success);

    // ─── Errors ───────────────────────────────────────────────────────
    error HeroAlreadyRegistered();
    error HeroNotRegistered();
    error AlreadyInFellowship();
    error NotInFellowship();
    error FellowshipFull();
    error FellowshipNotActive();
    error NotFellowshipLeader();
    error QuestAlreadyActive();
    error QuestNotActive();
    error InsufficientPower();
    error QuestNotReady();
    error InvalidLocation();
    error MustBeAtLocation();
    error NotARingBearer();
    error OneRingQuestAlreadyActive();
    error MustHaveTheOneRing();

    modifier onlyRegistered() {
        _onlyRegistered();
        _;
    }

    modifier onlyFellowshipLeader(uint256 fellowshipId) {
        _onlyFellowshipLeader(fellowshipId);
        _;
    }

    function _onlyRegistered() internal view {
        if (bytes(heroes[msg.sender].title).length == 0) revert HeroNotRegistered();
    }

    function _onlyFellowshipLeader(uint256 fellowshipId) internal view {
        if (fellowships[fellowshipId].leader != msg.sender) revert NotFellowshipLeader();
    }

    constructor(address _ringsOfPower) {
        ringsOfPower = RingsOfPower(_ringsOfPower);
    }

    // ─── Hero Registration ────────────────────────────────────────────

    /// @notice Register as a hero of Middle Earth
    /// @param title Your heroic title (e.g., "Strider", "Mithrandir")
    function registerHero(string calldata title) external {
        if (bytes(heroes[msg.sender].title).length != 0) revert HeroAlreadyRegistered();

        heroes[msg.sender] = Hero({
            title: title,
            xp: 0,
            questsCompleted: 0,
            questsFailed: 0,
            location: Location.TheShire,
            inFellowship: false,
            fellowshipId: 0
        });

        emit HeroRegistered(msg.sender, title);
    }

    // ─── Fellowship Management ────────────────────────────────────────

    /// @notice Form a new fellowship
    /// @param name The name of the fellowship (e.g., "Fellowship of the Ring")
    function formFellowship(string calldata name) external onlyRegistered returns (uint256) {
        if (heroes[msg.sender].inFellowship) revert AlreadyInFellowship();

        uint256 id = nextFellowshipId++;
        Fellowship storage f = fellowships[id];
        f.name = name;
        f.leader = msg.sender;
        f.active = true;
        f.formedAt = block.number;
        f.currentLocation = heroes[msg.sender].location;
        f.members.push(msg.sender);

        heroes[msg.sender].inFellowship = true;
        heroes[msg.sender].fellowshipId = id;
        fellowshipMembers[id][msg.sender] = true;

        _updateFellowshipPower(id);

        emit FellowshipFormed(id, name, msg.sender);
        return id;
    }

    /// @notice Join an existing fellowship
    /// @param fellowshipId The fellowship to join
    function joinFellowship(uint256 fellowshipId) external onlyRegistered {
        Fellowship storage f = fellowships[fellowshipId];
        if (!f.active) revert FellowshipNotActive();
        if (heroes[msg.sender].inFellowship) revert AlreadyInFellowship();
        if (f.members.length >= MAX_FELLOWSHIP_SIZE) revert FellowshipFull();
        if (heroes[msg.sender].location != f.currentLocation) revert MustBeAtLocation();

        f.members.push(msg.sender);
        heroes[msg.sender].inFellowship = true;
        heroes[msg.sender].fellowshipId = fellowshipId;
        fellowshipMembers[fellowshipId][msg.sender] = true;

        _updateFellowshipPower(fellowshipId);
        emit MemberJoined(fellowshipId, msg.sender);
    }

    /// @notice Leave your current fellowship
    function leaveFellowship() external onlyRegistered {
        if (!heroes[msg.sender].inFellowship) revert NotInFellowship();

        uint256 fId = heroes[msg.sender].fellowshipId;
        Fellowship storage f = fellowships[fId];

        _removeMember(fId, msg.sender);
        heroes[msg.sender].inFellowship = false;
        heroes[msg.sender].fellowshipId = 0;
        fellowshipMembers[fId][msg.sender] = false;

        // If leader leaves, disband
        if (f.leader == msg.sender || f.members.length == 0) {
            _disbandFellowship(fId);
        } else {
            _updateFellowshipPower(fId);
        }

        emit MemberLeft(fId, msg.sender);
    }

    /// @notice Disband a fellowship (leader only)
    function disbandFellowship(uint256 fellowshipId) external onlyFellowshipLeader(fellowshipId) {
        _disbandFellowship(fellowshipId);
    }

    // ─── Travel ───────────────────────────────────────────────────────

    /// @notice Travel to a new location in Middle Earth
    /// @param destination Where to travel
    function travel(Location destination) external onlyRegistered {
        if (heroes[msg.sender].inFellowship) revert AlreadyInFellowship(); // Must travel with fellowship or alone

        Location from = heroes[msg.sender].location;
        heroes[msg.sender].location = destination;
        emit HeroMoved(msg.sender, from, destination);
    }

    /// @notice Move the entire fellowship to a new location (leader only)
    function travelWithFellowship(uint256 fellowshipId, Location destination)
        external
        onlyFellowshipLeader(fellowshipId)
    {
        Fellowship storage f = fellowships[fellowshipId];
        if (!f.active) revert FellowshipNotActive();

        Location from = f.currentLocation;
        f.currentLocation = destination;

        for (uint256 i = 0; i < f.members.length; i++) {
            heroes[f.members[i]].location = destination;
            emit HeroMoved(f.members[i], from, destination);
        }
    }

    // ─── Quests ───────────────────────────────────────────────────────

    /// @notice Create a new quest
    function createQuest(
        string calldata name,
        string calldata description,
        Location destination,
        uint256 dangerLevel,
        uint256 requiredPower,
        uint256 rewardXp
    ) external returns (uint256) {
        uint256 id = nextQuestId++;
        quests[id] = Quest({
            name: name,
            description: description,
            fellowshipId: 0,
            status: QuestStatus.NotStarted,
            destination: destination,
            dangerLevel: dangerLevel,
            requiredPower: requiredPower,
            rewardXp: rewardXp,
            startedAt: 0
        });

        emit QuestCreated(id, name, destination);
        return id;
    }

    /// @notice Start a quest with your fellowship
    function startQuest(uint256 questId, uint256 fellowshipId) external onlyFellowshipLeader(fellowshipId) {
        Quest storage q = quests[questId];
        Fellowship storage f = fellowships[fellowshipId];

        if (q.status != QuestStatus.NotStarted) revert QuestAlreadyActive();
        if (!f.active) revert FellowshipNotActive();
        if (f.totalPower < q.requiredPower) revert InsufficientPower();

        q.fellowshipId = fellowshipId;
        q.status = QuestStatus.Active;
        q.startedAt = block.number;

        emit QuestStarted(questId, fellowshipId);
    }

    /// @notice Complete a quest (must wait QUEST_DURATION_BLOCKS)
    function completeQuest(uint256 questId) external {
        Quest storage q = quests[questId];
        if (q.status != QuestStatus.Active) revert QuestNotActive();
        if (block.number < q.startedAt + QUEST_DURATION_BLOCKS) revert QuestNotReady();

        Fellowship storage f = fellowships[q.fellowshipId];
        if (!fellowshipMembers[q.fellowshipId][msg.sender]) revert NotInFellowship();

        // Quest success based on power vs danger
        bool success = f.totalPower >= q.dangerLevel;

        if (success) {
            q.status = QuestStatus.Completed;

            // Distribute XP to all members
            for (uint256 i = 0; i < f.members.length; i++) {
                heroes[f.members[i]].xp += q.rewardXp;
                heroes[f.members[i]].questsCompleted++;
            }

            // Move fellowship to quest destination
            Location from = f.currentLocation;
            f.currentLocation = q.destination;
            for (uint256 i = 0; i < f.members.length; i++) {
                heroes[f.members[i]].location = q.destination;
                emit HeroMoved(f.members[i], from, q.destination);
            }

            emit QuestCompleted(questId, q.rewardXp);
        } else {
            q.status = QuestStatus.Failed;
            for (uint256 i = 0; i < f.members.length; i++) {
                heroes[f.members[i]].questsFailed++;
            }
            emit QuestFailed(questId);
        }
    }

    // ─── Mount Doom - The Final Quest ─────────────────────────────────

    /// @notice Embark on the quest to destroy The One Ring at Mount Doom
    /// @param fellowshipId The fellowship attempting the quest
    function journeyToMountDoom(uint256 fellowshipId) external onlyFellowshipLeader(fellowshipId) {
        if (oneRingQuestActive) revert OneRingQuestAlreadyActive();

        Fellowship storage f = fellowships[fellowshipId];
        if (!f.active) revert FellowshipNotActive();

        // Someone in the fellowship must hold The One Ring
        bool hasOneRing = false;
        for (uint256 i = 0; i < f.members.length; i++) {
            if (_holdsOneRing(f.members[i])) {
                hasOneRing = true;
                break;
            }
        }
        if (!hasOneRing) revert MustHaveTheOneRing();

        oneRingQuestActive = true;
        oneRingQuestFellowship = fellowshipId;
        mountDoomAttempts++;

        // Move fellowship to Mordor
        Location from = f.currentLocation;
        f.currentLocation = Location.MountDoom;
        for (uint256 i = 0; i < f.members.length; i++) {
            heroes[f.members[i]].location = Location.MountDoom;
            emit HeroMoved(f.members[i], from, Location.MountDoom);
        }
    }

    /// @notice Destroy The One Ring at Mount Doom (the ring bearer must call this)
    function destroyTheOneRing() external {
        if (!oneRingQuestActive) revert QuestNotActive();
        if (!_holdsOneRing(msg.sender)) revert MustHaveTheOneRing();
        if (!fellowshipMembers[oneRingQuestFellowship][msg.sender]) revert NotInFellowship();

        // The ring bearer casts it into the fire
        ringsOfPower.castIntoMountDoom();

        oneRingQuestActive = false;

        // Massive XP reward for all fellowship members
        Fellowship storage f = fellowships[oneRingQuestFellowship];
        for (uint256 i = 0; i < f.members.length; i++) {
            heroes[f.members[i]].xp += 10000;
            heroes[f.members[i]].questsCompleted++;
        }

        emit MountDoomAttempted(oneRingQuestFellowship, true);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getFellowshipMembers(uint256 fellowshipId) external view returns (address[] memory) {
        return fellowships[fellowshipId].members;
    }

    function getHero(address hero) external view returns (Hero memory) {
        return heroes[hero];
    }

    function getFellowshipPower(uint256 fellowshipId) external view returns (uint256) {
        return fellowships[fellowshipId].totalPower;
    }

    function isFellowshipMember(uint256 fellowshipId, address member) external view returns (bool) {
        return fellowshipMembers[fellowshipId][member];
    }

    // ─── Internal ─────────────────────────────────────────────────────

    function _holdsOneRing(address bearer) internal view returns (bool) {
        try ringsOfPower.ownerOf(20) returns (address owner) {
            return owner == bearer;
        } catch {
            return false;
        }
    }

    function _updateFellowshipPower(uint256 fellowshipId) internal {
        Fellowship storage f = fellowships[fellowshipId];
        uint256 totalPower = 0;

        for (uint256 i = 0; i < f.members.length; i++) {
            address member = f.members[i];
            totalPower += heroes[member].xp;

            // Add ring power if they hold any rings
            uint256 ringBalance = ringsOfPower.balanceOf(member);
            for (uint256 j = 0; j < ringBalance; j++) {
                uint256 ringId = ringsOfPower.tokenOfOwnerByIndex(member, j);
                totalPower += ringsOfPower.getRingPower(ringId);
            }
        }

        f.totalPower = totalPower;
    }

    function _removeMember(uint256 fellowshipId, address member) internal {
        Fellowship storage f = fellowships[fellowshipId];
        for (uint256 i = 0; i < f.members.length; i++) {
            if (f.members[i] == member) {
                f.members[i] = f.members[f.members.length - 1];
                f.members.pop();
                break;
            }
        }
    }

    function _disbandFellowship(uint256 fellowshipId) internal {
        Fellowship storage f = fellowships[fellowshipId];
        for (uint256 i = 0; i < f.members.length; i++) {
            heroes[f.members[i]].inFellowship = false;
            heroes[f.members[i]].fellowshipId = 0;
            fellowshipMembers[fellowshipId][f.members[i]] = false;
        }
        f.active = false;
        emit FellowshipDisbanded(fellowshipId);
    }
}
