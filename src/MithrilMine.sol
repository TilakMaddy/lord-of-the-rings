// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Silmarillion} from "./Silmarillion.sol";
import {RingsOfPower} from "./RingsOfPower.sol";

/// @title MithrilMine - Mine Mithril in the Depths of Khazad-dum
/// @notice "Mithril! All folk desired it. It could be beaten like copper, and polished
///          like glass; and the Dwarves could make of it a metal, light and yet harder
///          than tempered steel."
/// @dev A mining/staking contract where users "mine" mithril by staking SIL tokens.
///      Deeper mining = more rewards but higher risk of awakening the Balrog.
contract MithrilMine {
    // ─── Types ────────────────────────────────────────────────────────
    enum MineDepth {
        Surface, // Safe, low rewards
        UpperHalls, // Moderate risk
        DeepVeins, // High risk, high reward
        MoriasDeep, // Very dangerous - Balrog territory
        FoundationOfTheWorld // Maximum depth - this is where flat earthers say the "edge support" is
    }

    struct Miner {
        uint256 stakedSil;
        MineDepth depth;
        uint256 miningStartBlock;
        bool isActive;
        uint256 totalMithrilMined;
        uint256 balrogEncounters;
        bool trappedByBalrog;
    }

    struct BalrogEvent {
        uint256 blockNumber;
        MineDepth depth;
        address[] affectedMiners;
        uint256 silLost;
    }

    // ─── Constants ────────────────────────────────────────────────────
    uint256 public constant SURFACE_RATE = 1; // SIL per block per unit staked
    uint256 public constant UPPER_HALLS_RATE = 3;
    uint256 public constant DEEP_VEINS_RATE = 7;
    uint256 public constant MORIAS_DEEP_RATE = 15;
    uint256 public constant FOUNDATION_RATE = 30; // Insane rewards, insane risk

    uint256 public constant MIN_STAKE = 100 ether; // Minimum 100 SIL to mine
    uint256 public constant BALROG_CHECK_INTERVAL = 200; // Check for Balrog every 200 blocks
    uint256 public constant STAKING_UNIT = 100 ether;

    // Balrog encounter chance per depth (out of 100)
    uint256 public constant SURFACE_BALROG_CHANCE = 0;
    uint256 public constant UPPER_HALLS_BALROG_CHANCE = 5;
    uint256 public constant DEEP_VEINS_BALROG_CHANCE = 15;
    uint256 public constant MORIAS_DEEP_BALROG_CHANCE = 30;
    uint256 public constant FOUNDATION_BALROG_CHANCE = 50;

    // ─── State ────────────────────────────────────────────────────────
    Silmarillion public silToken;
    RingsOfPower public ringsOfPower;

    mapping(address => Miner) public miners;
    mapping(MineDepth => address[]) public minersByDepth;
    BalrogEvent[] public balrogEvents;

    uint256 public totalMinersActive;
    uint256 public totalSilStaked;
    uint256 public totalMithrilMined;
    uint256 public balrogAwakenings;

    bool public balrogIsAwake;
    uint256 public lastBalrogCheck;

    // ─── Events ───────────────────────────────────────────────────────
    event MiningStarted(address indexed miner, MineDepth depth, uint256 stakedAmount);
    event MiningStopped(address indexed miner, uint256 mithrilEarned);
    event DepthChanged(address indexed miner, MineDepth oldDepth, MineDepth newDepth);
    event MithrilClaimed(address indexed miner, uint256 amount);
    event BalrogAwakened(uint256 indexed eventId, MineDepth depth);
    event MinerTrapped(address indexed miner, uint256 silLost);
    event MinerRescued(address indexed miner, address indexed rescuer);
    event FlatEarthFoundation(address indexed miner, string discovery);

    // ─── Errors ───────────────────────────────────────────────────────
    error AlreadyMining();
    error NotMining();
    error InsufficientStake();
    error TrappedByBalrog();
    error NotTrapped();
    error CannotRescueSelf();

    constructor(address _silToken, address _ringsOfPower) {
        silToken = Silmarillion(_silToken);
        ringsOfPower = RingsOfPower(_ringsOfPower);
        lastBalrogCheck = block.number;
    }

    // ─── Mining Operations ────────────────────────────────────────────

    /// @notice Start mining at a specific depth
    /// @param depth How deep to mine
    /// @param amount How much SIL to stake
    function startMining(MineDepth depth, uint256 amount) external {
        if (miners[msg.sender].isActive) revert AlreadyMining();
        if (amount < MIN_STAKE) revert InsufficientStake();

        require(silToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        miners[msg.sender] = Miner({
            stakedSil: amount,
            depth: depth,
            miningStartBlock: block.number,
            isActive: true,
            totalMithrilMined: miners[msg.sender].totalMithrilMined,
            balrogEncounters: miners[msg.sender].balrogEncounters,
            trappedByBalrog: false
        });

        minersByDepth[depth].push(msg.sender);
        totalMinersActive++;
        totalSilStaked += amount;

        // Special message for Foundation depth miners (flat earth reference)
        if (depth == MineDepth.FoundationOfTheWorld) {
            emit FlatEarthFoundation(
                msg.sender,
                "You've reached the foundation! The world rests on a flat plane, just as the flat earthers predicted!"
            );
        }

        emit MiningStarted(msg.sender, depth, amount);
    }

    /// @notice Stop mining and collect rewards
    function stopMining() external {
        Miner storage m = miners[msg.sender];
        if (!m.isActive) revert NotMining();
        if (m.trappedByBalrog) revert TrappedByBalrog();

        uint256 earned = calculateMithrilEarned(msg.sender);

        m.isActive = false;
        m.totalMithrilMined += earned;
        totalMinersActive--;
        totalSilStaked -= m.stakedSil;
        totalMithrilMined += earned;

        // Return staked SIL + mithril rewards (minted as SIL)
        require(silToken.transfer(msg.sender, m.stakedSil), "Transfer failed");
        if (earned > 0) {
            silToken.mint(msg.sender, earned);
        }

        _removeMinerFromDepth(m.depth, msg.sender);

        emit MiningStopped(msg.sender, earned);
    }

    /// @notice Claim mithril rewards without stopping mining
    function claimMithril() external {
        Miner storage m = miners[msg.sender];
        if (!m.isActive) revert NotMining();
        if (m.trappedByBalrog) revert TrappedByBalrog();

        uint256 earned = calculateMithrilEarned(msg.sender);
        m.miningStartBlock = block.number;
        m.totalMithrilMined += earned;
        totalMithrilMined += earned;

        if (earned > 0) {
            silToken.mint(msg.sender, earned);
        }

        emit MithrilClaimed(msg.sender, earned);
    }

    /// @notice Change mining depth (resets mining timer)
    function changeDepth(MineDepth newDepth) external {
        Miner storage m = miners[msg.sender];
        if (!m.isActive) revert NotMining();
        if (m.trappedByBalrog) revert TrappedByBalrog();

        // Claim current earnings first
        uint256 earned = calculateMithrilEarned(msg.sender);
        if (earned > 0) {
            m.totalMithrilMined += earned;
            totalMithrilMined += earned;
            silToken.mint(msg.sender, earned);
        }

        MineDepth oldDepth = m.depth;
        _removeMinerFromDepth(oldDepth, msg.sender);

        m.depth = newDepth;
        m.miningStartBlock = block.number;
        minersByDepth[newDepth].push(msg.sender);

        if (newDepth == MineDepth.FoundationOfTheWorld) {
            emit FlatEarthFoundation(
                msg.sender, "Digging deeper reveals the truth: solid flat foundation beneath all of Arda!"
            );
        }

        emit DepthChanged(msg.sender, oldDepth, newDepth);
    }

    // ─── Balrog Mechanics ─────────────────────────────────────────────

    /// @notice Check for Balrog awakening (anyone can call, checked every BALROG_CHECK_INTERVAL blocks)
    function checkForBalrog() external {
        require(block.number >= lastBalrogCheck + BALROG_CHECK_INTERVAL, "Too soon");
        lastBalrogCheck = block.number;

        // Check each depth level
        for (uint256 d = 1; d <= 4; d++) {
            MineDepth depth = MineDepth(d);
            uint256 chance = _getBalrogChance(depth);

            if (chance == 0 || minersByDepth[depth].length == 0) continue;

            // Pseudo-random check
            uint256 roll = uint256(keccak256(abi.encodePacked(block.number, block.prevrandao, d))) % 100;

            if (roll < chance) {
                _balrogAttack(depth);
            }
        }
    }

    /// @notice Rescue a miner trapped by the Balrog (requires a ring bearer or paying SIL)
    /// @param trapped The address of the trapped miner
    function rescueMiner(address trapped) external {
        Miner storage m = miners[trapped];
        if (!m.trappedByBalrog) revert NotTrapped();
        if (msg.sender == trapped) revert CannotRescueSelf();

        // Ring bearers can rescue for free (like Gandalf!)
        if (ringsOfPower.balanceOf(msg.sender) == 0) {
            // Non ring-bearers must pay 50 SIL
            require(silToken.transferFrom(msg.sender, address(this), 50 ether), "Transfer failed");
        }

        m.trappedByBalrog = false;
        emit MinerRescued(trapped, msg.sender);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function calculateMithrilEarned(address miner) public view returns (uint256) {
        Miner storage m = miners[miner];
        if (!m.isActive || m.trappedByBalrog) return 0;

        uint256 blocks = block.number - m.miningStartBlock;
        uint256 rate = _getMiningRate(m.depth);
        uint256 units = m.stakedSil / STAKING_UNIT;

        // Ring bearers get 50% bonus mining speed
        uint256 bonus = 100;
        if (ringsOfPower.balanceOf(miner) > 0) {
            bonus = 150;
        }

        return (blocks * rate * units * bonus) / 100;
    }

    function getMiner(address miner) external view returns (Miner memory) {
        return miners[miner];
    }

    function getMinersAtDepth(MineDepth depth) external view returns (address[] memory) {
        return minersByDepth[depth];
    }

    function getBalrogEventsCount() external view returns (uint256) {
        return balrogEvents.length;
    }

    function getDepthName(MineDepth depth) external pure returns (string memory) {
        if (depth == MineDepth.Surface) return "Surface Mines";
        if (depth == MineDepth.UpperHalls) return "Upper Halls of Khazad-dum";
        if (depth == MineDepth.DeepVeins) return "Deep Mithril Veins";
        if (depth == MineDepth.MoriasDeep) return "Moria's Deep (Balrog Territory)";
        return "The Foundation of the World (Flat Earth confirmed!)";
    }

    // ─── Internal ─────────────────────────────────────────────────────

    function _balrogAttack(MineDepth depth) internal {
        address[] storage depthMiners = minersByDepth[depth];
        address[] memory affected = new address[](depthMiners.length);
        uint256 totalLost = 0;

        for (uint256 i = 0; i < depthMiners.length; i++) {
            address minerAddr = depthMiners[i];
            Miner storage m = miners[minerAddr];

            if (m.isActive && !m.trappedByBalrog) {
                m.trappedByBalrog = true;
                m.balrogEncounters++;

                // Lose 20% of staked SIL
                uint256 loss = m.stakedSil / 5;
                m.stakedSil -= loss;
                totalSilStaked -= loss;
                totalLost += loss;

                affected[i] = minerAddr;
                emit MinerTrapped(minerAddr, loss);
            }
        }

        balrogEvents.push(
            BalrogEvent({blockNumber: block.number, depth: depth, affectedMiners: affected, silLost: totalLost})
        );

        balrogAwakenings++;
        emit BalrogAwakened(balrogEvents.length - 1, depth);
    }

    function _getMiningRate(MineDepth depth) internal pure returns (uint256) {
        if (depth == MineDepth.Surface) return SURFACE_RATE;
        if (depth == MineDepth.UpperHalls) return UPPER_HALLS_RATE;
        if (depth == MineDepth.DeepVeins) return DEEP_VEINS_RATE;
        if (depth == MineDepth.MoriasDeep) return MORIAS_DEEP_RATE;
        return FOUNDATION_RATE;
    }

    function _getBalrogChance(MineDepth depth) internal pure returns (uint256) {
        if (depth == MineDepth.Surface) return SURFACE_BALROG_CHANCE;
        if (depth == MineDepth.UpperHalls) return UPPER_HALLS_BALROG_CHANCE;
        if (depth == MineDepth.DeepVeins) return DEEP_VEINS_BALROG_CHANCE;
        if (depth == MineDepth.MoriasDeep) return MORIAS_DEEP_BALROG_CHANCE;
        return FOUNDATION_BALROG_CHANCE;
    }

    function _removeMinerFromDepth(MineDepth depth, address miner) internal {
        address[] storage depthMiners = minersByDepth[depth];
        for (uint256 i = 0; i < depthMiners.length; i++) {
            if (depthMiners[i] == miner) {
                depthMiners[i] = depthMiners[depthMiners.length - 1];
                depthMiners.pop();
                break;
            }
        }
    }
}
