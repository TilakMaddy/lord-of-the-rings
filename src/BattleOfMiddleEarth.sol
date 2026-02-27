// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RingsOfPower} from "./RingsOfPower.sol";
import {MiddleEarth} from "./MiddleEarth.sol";
import {Silmarillion} from "./Silmarillion.sol";

/// @title BattleOfMiddleEarth - Epic Battles Between the Forces of Light and Dark
/// @notice "A day may come when the courage of men fails... but it is not this day!"
/// @dev PvP and PvE battle system where heroes fight with ring power, XP, and strategy.
///      Includes siege battles, duels, and the great battles from the lore.
contract BattleOfMiddleEarth {
    // ─── Types ────────────────────────────────────────────────────────
    enum BattleType {
        Duel,
        Skirmish,
        Siege,
        GreatBattle
    }
    enum BattleStatus {
        Pending,
        Active,
        Resolved
    }
    enum Outcome {
        Undecided,
        ChallengerWins,
        DefenderWins,
        Draw
    }

    struct BattleStats {
        uint256 attack;
        uint256 defense;
        uint256 ringPower;
        uint256 xpBonus;
        uint256 totalPower;
    }

    struct Battle {
        uint256 id;
        BattleType battleType;
        BattleStatus status;
        Outcome outcome;
        address challenger;
        address defender;
        uint256 wager; // SIL wagered
        uint256 startBlock;
        uint256 resolveBlock; // Block when battle can be resolved
        string battleName;
    }

    struct GreatBattleConfig {
        string name;
        string description;
        uint256 minParticipants;
        uint256 reward;
        MiddleEarth.Location location;
        bool isActive;
    }

    struct Warrior {
        uint256 wins;
        uint256 losses;
        uint256 draws;
        uint256 totalWagersWon;
        uint256 totalWagersLost;
        string warTitle; // Earned through victories
    }

    // ─── Constants ────────────────────────────────────────────────────
    uint256 public constant DUEL_DURATION = 10; // blocks
    uint256 public constant SKIRMISH_DURATION = 25;
    uint256 public constant SIEGE_DURATION = 50;
    uint256 public constant GREAT_BATTLE_DURATION = 100;
    uint256 public constant MIN_WAGER = 10 ether; // 10 SIL

    // War titles earned at milestones
    uint256 public constant TITLE_WARRIOR = 5; // 5 wins
    uint256 public constant TITLE_CHAMPION = 15; // 15 wins
    uint256 public constant TITLE_WARLORD = 30; // 30 wins
    uint256 public constant TITLE_CONQUEROR = 50; // 50 wins
    uint256 public constant TITLE_LEGEND = 100; // 100 wins

    // ─── State ────────────────────────────────────────────────────────
    RingsOfPower public ringsOfPower;
    MiddleEarth public middleEarth;
    Silmarillion public silToken;

    mapping(uint256 => Battle) public battles;
    mapping(address => Warrior) public warriors;
    mapping(uint256 => GreatBattleConfig) public greatBattles;
    mapping(uint256 => address[]) public greatBattleParticipants; // light side
    mapping(uint256 => address[]) public greatBattleDarkSide;
    mapping(uint256 => mapping(address => bool)) public hasJoinedLight;
    mapping(uint256 => mapping(address => bool)) public hasJoinedDark;

    uint256 public constant MAX_PARTICIPANTS = 500;

    uint256 public nextBattleId = 1;
    uint256 public nextGreatBattleId = 1;
    uint256 public totalBattles;
    uint256 public totalWagered;

    // ─── Events ───────────────────────────────────────────────────────
    event BattleCreated(
        uint256 indexed id, BattleType battleType, address indexed challenger, address indexed defender
    );
    event BattleAccepted(uint256 indexed id, address indexed defender);
    event BattleResolved(uint256 indexed id, Outcome outcome, address winner);
    event WarTitleEarned(address indexed warrior, string title);
    event GreatBattleCreated(uint256 indexed id, string name);
    event GreatBattleJoined(uint256 indexed id, address indexed participant, bool lightSide);
    event GreatBattleResolved(uint256 indexed id, bool lightSideWins);

    // ─── Errors ───────────────────────────────────────────────────────
    error BattleNotPending();
    error BattleNotActive();
    error BattleNotReady();
    error CannotFightSelf();
    error InsufficientWager();
    error NotBattleParticipant();
    error InvalidBattle();

    constructor(address _ringsOfPower, address _middleEarth, address _silToken) {
        ringsOfPower = RingsOfPower(_ringsOfPower);
        middleEarth = MiddleEarth(_middleEarth);
        silToken = Silmarillion(_silToken);

        _initializeGreatBattles();
    }

    function _initializeGreatBattles() internal {
        greatBattles[1] = GreatBattleConfig({
            name: "Battle of the Last Alliance",
            description: "The final stand of Elves and Men against Sauron at the foot of Mount Doom",
            minParticipants: 3,
            reward: 1000 ether,
            location: MiddleEarth.Location.Mordor,
            isActive: true
        });

        greatBattles[2] = GreatBattleConfig({
            name: "Battle of Helm's Deep",
            description: "Defend the fortress of the Hornburg against Saruman's Uruk-hai",
            minParticipants: 2,
            reward: 500 ether,
            location: MiddleEarth.Location.Rohan,
            isActive: true
        });

        greatBattles[3] = GreatBattleConfig({
            name: "Battle of Pelennor Fields",
            description: "The greatest battle of the War of the Ring before the gates of Minas Tirith",
            minParticipants: 4,
            reward: 750 ether,
            location: MiddleEarth.Location.Gondor,
            isActive: true
        });

        greatBattles[4] = GreatBattleConfig({
            name: "Battle of the Black Gate",
            description: "The final diversion at the Morannon to buy time for the Ring-bearer",
            minParticipants: 3,
            reward: 2000 ether,
            location: MiddleEarth.Location.Mordor,
            isActive: true
        });

        greatBattles[5] = GreatBattleConfig({
            name: "Battle at the Edge of the World",
            description: "Flat earthers vs Globe earthers clash at the theoretical edge of Arda!",
            minParticipants: 2,
            reward: 420 ether,
            location: MiddleEarth.Location.TheVoid,
            isActive: true
        });

        nextGreatBattleId = 6;
    }

    // ─── Duels ────────────────────────────────────────────────────────

    /// @notice Challenge another warrior to a duel
    /// @param defender Who to fight
    /// @param wager SIL tokens to wager
    /// @param battleType Type of battle
    function challenge(address defender, uint256 wager, BattleType battleType, string calldata battleName)
        external
        returns (uint256)
    {
        if (defender == msg.sender) revert CannotFightSelf();
        if (wager < MIN_WAGER) revert InsufficientWager();

        require(silToken.transferFrom(msg.sender, address(this), wager), "Transfer failed");

        uint256 id = nextBattleId++;

        battles[id] = Battle({
            id: id,
            battleType: battleType,
            status: BattleStatus.Pending,
            outcome: Outcome.Undecided,
            challenger: msg.sender,
            defender: defender,
            wager: wager,
            startBlock: 0,
            resolveBlock: 0,
            battleName: battleName
        });

        emit BattleCreated(id, battleType, msg.sender, defender);
        return id;
    }

    /// @notice Accept a battle challenge
    function acceptChallenge(uint256 battleId) external {
        Battle storage b = battles[battleId];
        if (b.status != BattleStatus.Pending) revert BattleNotPending();
        if (b.defender != msg.sender) revert NotBattleParticipant();

        require(silToken.transferFrom(msg.sender, address(this), b.wager), "Transfer failed");

        b.status = BattleStatus.Active;
        b.startBlock = block.number;
        b.resolveBlock = block.number + _getBattleDuration(b.battleType);

        totalBattles++;
        totalWagered += b.wager * 2;

        emit BattleAccepted(battleId, msg.sender);
    }

    /// @notice Resolve a battle after the duration has passed
    function resolveBattle(uint256 battleId) external {
        Battle storage b = battles[battleId];
        if (b.status != BattleStatus.Active) revert BattleNotActive();
        if (block.number < b.resolveBlock) revert BattleNotReady();

        BattleStats memory challengerStats = _calculateBattleStats(b.challenger);
        BattleStats memory defenderStats = _calculateBattleStats(b.defender);

        // Add randomness factor
        uint256 challengerRoll = uint256(keccak256(abi.encodePacked(block.number, b.challenger, battleId))) % 20;
        uint256 defenderRoll = uint256(keccak256(abi.encodePacked(block.number, b.defender, battleId))) % 20;

        uint256 challengerTotal = challengerStats.totalPower + challengerRoll;
        uint256 defenderTotal = defenderStats.totalPower + defenderRoll;

        b.status = BattleStatus.Resolved;
        uint256 totalWager = b.wager * 2;

        if (challengerTotal > defenderTotal) {
            b.outcome = Outcome.ChallengerWins;
            _recordVictory(b.challenger, b.defender, totalWager);
            require(silToken.transfer(b.challenger, totalWager), "Transfer failed");
            emit BattleResolved(battleId, Outcome.ChallengerWins, b.challenger);
        } else if (defenderTotal > challengerTotal) {
            b.outcome = Outcome.DefenderWins;
            _recordVictory(b.defender, b.challenger, totalWager);
            require(silToken.transfer(b.defender, totalWager), "Transfer failed");
            emit BattleResolved(battleId, Outcome.DefenderWins, b.defender);
        } else {
            b.outcome = Outcome.Draw;
            warriors[b.challenger].draws++;
            warriors[b.defender].draws++;
            // Return wagers
            require(silToken.transfer(b.challenger, b.wager), "Transfer failed");
            require(silToken.transfer(b.defender, b.wager), "Transfer failed");
            emit BattleResolved(battleId, Outcome.Draw, address(0));
        }
    }

    /// @notice Cancel a pending (unaccepted) battle and reclaim wager
    function cancelChallenge(uint256 battleId) external {
        Battle storage b = battles[battleId];
        if (b.status != BattleStatus.Pending) revert BattleNotPending();
        if (b.challenger != msg.sender) revert NotBattleParticipant();

        b.status = BattleStatus.Resolved;
        b.outcome = Outcome.Draw;
        require(silToken.transfer(msg.sender, b.wager), "Transfer failed");
    }

    // ─── Great Battles ────────────────────────────────────────────────

    /// @notice Join a Great Battle on the light side
    function joinGreatBattleLight(uint256 greatBattleId) external {
        require(greatBattles[greatBattleId].isActive, "Battle not active");
        require(!hasJoinedLight[greatBattleId][msg.sender], "Already joined light side");
        require(!hasJoinedDark[greatBattleId][msg.sender], "Already joined dark side");
        require(greatBattleParticipants[greatBattleId].length < MAX_PARTICIPANTS, "Max participants reached");
        hasJoinedLight[greatBattleId][msg.sender] = true;
        greatBattleParticipants[greatBattleId].push(msg.sender);
        emit GreatBattleJoined(greatBattleId, msg.sender, true);
    }

    /// @notice Join a Great Battle on the dark side
    function joinGreatBattleDark(uint256 greatBattleId) external {
        require(greatBattles[greatBattleId].isActive, "Battle not active");
        require(!hasJoinedDark[greatBattleId][msg.sender], "Already joined dark side");
        require(!hasJoinedLight[greatBattleId][msg.sender], "Already joined light side");
        require(greatBattleDarkSide[greatBattleId].length < MAX_PARTICIPANTS, "Max participants reached");
        hasJoinedDark[greatBattleId][msg.sender] = true;
        greatBattleDarkSide[greatBattleId].push(msg.sender);
        emit GreatBattleJoined(greatBattleId, msg.sender, false);
    }

    /// @notice Resolve a Great Battle
    function resolveGreatBattle(uint256 greatBattleId) external {
        GreatBattleConfig storage config = greatBattles[greatBattleId];
        require(config.isActive, "Battle not active");

        address[] storage lightSide = greatBattleParticipants[greatBattleId];
        address[] storage darkSide = greatBattleDarkSide[greatBattleId];

        require(
            lightSide.length >= config.minParticipants && darkSide.length >= config.minParticipants,
            "Not enough participants"
        );

        // Calculate total power for each side
        uint256 lightPower = 0;
        uint256 darkPower = 0;

        for (uint256 i = 0; i < lightSide.length; i++) {
            lightPower += _calculateBattleStats(lightSide[i]).totalPower;
        }
        for (uint256 i = 0; i < darkSide.length; i++) {
            darkPower += _calculateBattleStats(darkSide[i]).totalPower;
        }

        // Add randomness
        uint256 lightRoll =
            uint256(keccak256(abi.encodePacked(block.number, "light", greatBattleId))) % (lightSide.length * 10);
        uint256 darkRoll =
            uint256(keccak256(abi.encodePacked(block.number, "dark", greatBattleId))) % (darkSide.length * 10);

        lightPower += lightRoll;
        darkPower += darkRoll;

        bool lightWins = lightPower >= darkPower;
        config.isActive = false;

        // Distribute rewards to winning side
        address[] storage winners = lightWins ? lightSide : darkSide;
        require(winners.length > 0, "No winners");
        require(winners.length <= MAX_PARTICIPANTS, "Invalid winners length");
        uint256 rewardPerWinner = config.reward / winners.length;

        for (uint256 i = 0; i < winners.length; i++) {
            silToken.mint(winners[i], rewardPerWinner);
            warriors[winners[i]].wins++;
            _checkWarTitle(winners[i]);
        }

        // Record losses
        address[] storage losers = lightWins ? darkSide : lightSide;
        for (uint256 i = 0; i < losers.length; i++) {
            warriors[losers[i]].losses++;
        }

        emit GreatBattleResolved(greatBattleId, lightWins);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getBattle(uint256 battleId) external view returns (Battle memory) {
        return battles[battleId];
    }

    function getWarrior(address warrior) external view returns (Warrior memory) {
        return warriors[warrior];
    }

    function getBattleStats(address warrior) external view returns (BattleStats memory) {
        return _calculateBattleStats(warrior);
    }

    function getGreatBattle(uint256 id) external view returns (GreatBattleConfig memory) {
        return greatBattles[id];
    }

    function getGreatBattleParticipants(uint256 id)
        external
        view
        returns (address[] memory light, address[] memory dark)
    {
        return (greatBattleParticipants[id], greatBattleDarkSide[id]);
    }

    // ─── Internal ─────────────────────────────────────────────────────

    function _calculateBattleStats(address warrior) internal view returns (BattleStats memory stats) {
        // Base stats from XP
        MiddleEarth.Hero memory hero = middleEarth.getHero(warrior);
        stats.xpBonus = hero.xp / 10;

        // Ring power
        uint256 ringBalance = ringsOfPower.balanceOf(warrior);
        for (uint256 i = 0; i < ringBalance; i++) {
            uint256 ringId = ringsOfPower.tokenOfOwnerByIndex(warrior, i);
            stats.ringPower += ringsOfPower.getRingPower(ringId);
        }

        // The One Ring gives massive advantage
        try ringsOfPower.ownerOf(20) returns (address oneRingBearer) {
            if (oneRingBearer == warrior) {
                stats.ringPower += 500; // Massive bonus
            }
        } catch {}

        // Attack and defense from wins/losses
        stats.attack = warriors[warrior].wins * 2 + 10;
        stats.defense = warriors[warrior].wins + warriors[warrior].draws + 5;

        stats.totalPower = stats.attack + stats.defense + stats.ringPower + stats.xpBonus;
    }

    function _recordVictory(address winner, address loser, uint256 wager) internal {
        warriors[winner].wins++;
        warriors[winner].totalWagersWon += wager;
        warriors[loser].losses++;
        warriors[loser].totalWagersLost += wager;

        _checkWarTitle(winner);
    }

    function _checkWarTitle(address warrior) internal {
        uint256 wins = warriors[warrior].wins;
        string memory title = "";

        if (wins >= TITLE_LEGEND) {
            title = "Legend of Middle Earth";
        } else if (wins >= TITLE_CONQUEROR) {
            title = "Conqueror of Arda";
        } else if (wins >= TITLE_WARLORD) {
            title = "Warlord";
        } else if (wins >= TITLE_CHAMPION) {
            title = "Champion of the Free Peoples";
        } else if (wins >= TITLE_WARRIOR) {
            title = "Warrior";
        }

        if (bytes(title).length > 0 && keccak256(bytes(warriors[warrior].warTitle)) != keccak256(bytes(title))) {
            warriors[warrior].warTitle = title;
            emit WarTitleEarned(warrior, title);
        }
    }

    function _getBattleDuration(BattleType bt) internal pure returns (uint256) {
        if (bt == BattleType.Duel) return DUEL_DURATION;
        if (bt == BattleType.Skirmish) return SKIRMISH_DURATION;
        if (bt == BattleType.Siege) return SIEGE_DURATION;
        return GREAT_BATTLE_DURATION;
    }
}
