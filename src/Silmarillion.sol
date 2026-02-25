// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RingsOfPower} from "./RingsOfPower.sol";

/// @title Silmarillion (SIL) - The Light of the Two Trees as an ERC-20 Token
/// @notice "The light of the Two Trees, Telperion and Laurelin, was captured in the
///          Silmarils by Feanor. Now that light is captured in tokens."
/// @dev The in-game currency of Middle Earth. Earned through quests, ring-bearing,
///      and flat earth activities. Used for governance, staking, and trade.
contract Silmarillion is ERC20, Ownable {
    // ─── State ────────────────────────────────────────────────────────
    RingsOfPower public ringsOfPower;

    uint256 public constant INITIAL_SUPPLY = 3_000_000 ether; // 3 million - for the 3 Silmarils
    uint256 public constant RING_BEARER_DAILY_REWARD = 100 ether;
    uint256 public constant BLOCKS_PER_DAY = 7200; // ~12 second blocks

    mapping(address => uint256) public lastClaimBlock;
    mapping(address => bool) public authorizedMinters; // MiddleEarth, FlatEarthSociety, etc.

    uint256 public totalBurned;

    // Morgoth's Theft: a drain mechanic where tokens are "stolen" to Morgoth's vault
    address public morgothsVault;
    uint256 public morgothsHoard;
    uint256 public constant MORGOTH_TAX_BPS = 100; // 1% tax on transfers, Morgoth takes his cut

    // Feanor's Oath: lock tokens for boosted rewards
    struct FeanorsOath {
        uint256 amount;
        uint256 lockedUntil;
        uint256 multiplier; // 1x = 100, 2x = 200, etc.
    }
    mapping(address => FeanorsOath) public oaths;
    uint256 public constant MIN_LOCK_BLOCKS = 50400; // ~7 days
    uint256 public constant MAX_LOCK_BLOCKS = 2_160_000; // ~300 days

    // ─── Events ───────────────────────────────────────────────────────
    event RingBearerRewardClaimed(address indexed bearer, uint256 amount);
    event MorgothTaxCollected(address indexed from, uint256 amount);
    event OathSworn(address indexed swearer, uint256 amount, uint256 lockedUntil, uint256 multiplier);
    event OathFulfilled(address indexed swearer, uint256 amount, uint256 bonus);
    event OathBroken(address indexed swearer, uint256 penalty);
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event MorgothsVaultSet(address indexed vault);

    // ─── Errors ───────────────────────────────────────────────────────
    error NotAuthorizedMinter();
    error NothingToClaim();
    error NotARingBearer();
    error OathAlreadySworn();
    error NoOathSworn();
    error OathNotExpired();
    error InvalidLockDuration();
    error InsufficientBalance();

    modifier onlyMinter() {
        _onlyMinter();
        _;
    }

    function _onlyMinter() internal view {
        if (!authorizedMinters[msg.sender] && msg.sender != owner()) revert NotAuthorizedMinter();
    }

    constructor(address _ringsOfPower) ERC20("Silmarillion", "SIL") Ownable(msg.sender) {
        ringsOfPower = RingsOfPower(_ringsOfPower);
        morgothsVault = address(this); // Morgoth's vault is the contract itself initially

        // Distribute initial supply: 1M each for the "three Silmarils"
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // ─── Ring Bearer Rewards ──────────────────────────────────────────

    /// @notice Ring bearers can claim daily SIL rewards based on their ring's power
    function claimRingBearerReward() external {
        uint256 ringBalance = ringsOfPower.balanceOf(msg.sender);
        if (ringBalance == 0) revert NotARingBearer();

        uint256 blocksSinceLastClaim = block.number - lastClaimBlock[msg.sender];
        if (blocksSinceLastClaim < BLOCKS_PER_DAY) revert NothingToClaim();

        // Calculate reward based on ring power
        uint256 totalPower = 0;
        for (uint256 i = 0; i < ringBalance; i++) {
            uint256 ringId = ringsOfPower.tokenOfOwnerByIndex(msg.sender, i);
            totalPower += ringsOfPower.getRingPower(ringId);
        }

        uint256 days_ = blocksSinceLastClaim / BLOCKS_PER_DAY;
        uint256 reward = (RING_BEARER_DAILY_REWARD * totalPower * days_) / 100;

        // Apply oath multiplier if applicable
        if (oaths[msg.sender].amount > 0 && block.number <= oaths[msg.sender].lockedUntil) {
            reward = (reward * oaths[msg.sender].multiplier) / 100;
        }

        lastClaimBlock[msg.sender] = block.number;
        _mint(msg.sender, reward);

        emit RingBearerRewardClaimed(msg.sender, reward);
    }

    // ─── Minting (for game contracts) ─────────────────────────────────

    /// @notice Authorized game contracts can mint SIL as rewards
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /// @notice Authorize a contract to mint SIL
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /// @notice Revoke minting authorization
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    // ─── Morgoth's Tax ────────────────────────────────────────────────

    /// @notice Set Morgoth's vault address
    function setMorgothsVault(address vault) external onlyOwner {
        morgothsVault = vault;
        emit MorgothsVaultSet(vault);
    }

    /// @dev Override transfer to apply Morgoth's tax
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && to != morgothsVault && from != morgothsVault) {
            uint256 tax = (value * MORGOTH_TAX_BPS) / 10000;
            if (tax > 0) {
                super._update(from, morgothsVault, tax);
                morgothsHoard += tax;
                value -= tax;
                emit MorgothTaxCollected(from, tax);
            }
        }
        super._update(from, to, value);
    }

    // ─── Feanor's Oath (Token Locking) ────────────────────────────────

    /// @notice Swear Feanor's Oath - lock SIL tokens for boosted ring bearer rewards
    /// @param amount Amount to lock
    /// @param lockBlocks How many blocks to lock for (min 50400, max 2160000)
    function swearOath(uint256 amount, uint256 lockBlocks) external {
        if (oaths[msg.sender].amount != 0) revert OathAlreadySworn();
        if (lockBlocks < MIN_LOCK_BLOCKS || lockBlocks > MAX_LOCK_BLOCKS) revert InvalidLockDuration();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        // Calculate multiplier: longer lock = higher multiplier (100-300)
        uint256 multiplier = 100 + ((lockBlocks - MIN_LOCK_BLOCKS) * 200) / (MAX_LOCK_BLOCKS - MIN_LOCK_BLOCKS);

        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);

        oaths[msg.sender] =
            FeanorsOath({amount: amount, lockedUntil: block.number + lockBlocks, multiplier: multiplier});

        emit OathSworn(msg.sender, amount, block.number + lockBlocks, multiplier);
    }

    /// @notice Fulfill your oath after the lock period - get tokens back + bonus
    function fulfillOath() external {
        FeanorsOath storage oath = oaths[msg.sender];
        if (oath.amount == 0) revert NoOathSworn();
        if (block.number < oath.lockedUntil) revert OathNotExpired();

        uint256 amount = oath.amount;
        uint256 bonus = (amount * (oath.multiplier - 100)) / 100;

        delete oaths[msg.sender];

        _transfer(address(this), msg.sender, amount);
        _mint(msg.sender, bonus);

        emit OathFulfilled(msg.sender, amount, bonus);
    }

    /// @notice Break your oath early - get tokens back with 50% penalty (burned)
    function breakOath() external {
        FeanorsOath storage oath = oaths[msg.sender];
        if (oath.amount == 0) revert NoOathSworn();

        uint256 amount = oath.amount;
        uint256 penalty = amount / 2;

        delete oaths[msg.sender];

        // Burn the penalty
        _burn(address(this), penalty);
        totalBurned += penalty;

        // Return the rest
        _transfer(address(this), msg.sender, amount - penalty);

        emit OathBroken(msg.sender, penalty);
    }

    // ─── Burn ─────────────────────────────────────────────────────────

    /// @notice Burn SIL tokens (like casting a Silmaril into the sea)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getOath(address swearer) external view returns (FeanorsOath memory) {
        return oaths[swearer];
    }

    function getMorgothsHoard() external view returns (uint256) {
        return morgothsHoard;
    }

    function isMinter(address account) external view returns (bool) {
        return authorizedMinters[account];
    }
}
