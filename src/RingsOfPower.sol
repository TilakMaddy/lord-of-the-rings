// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title RingsOfPower - The 20 Rings of Power as NFTs
/// @notice "Three Rings for the Elven-kings under the sky,
///          Seven for the Dwarf-lords in their halls of stone,
///          Nine for Mortal Men doomed to die,
///          One for the Dark Lord on his dark throne."
/// @dev Each ring has a race, power level, and corruption mechanic.
///      Holding a ring too long corrupts the bearer. The One Ring dominates all.
contract RingsOfPower is ERC721Enumerable, Ownable {
    // ─── Ring Types ───────────────────────────────────────────────────
    enum Race {
        Elven,
        Dwarven,
        Mortal,
        TheOneRing
    }

    struct Ring {
        string name;
        Race race;
        uint256 power;
        bool forged;
        bool destroyed;
        uint256 forgedAt;
    }

    struct BearerInfo {
        uint256 corruptionLevel; // 0-100, at 100 you become a wraith
        uint256 lastCorruptionTick; // block number of last corruption update
        bool isWraith;
    }

    // ─── State ────────────────────────────────────────────────────────
    uint256 public constant MAX_RINGS = 20;
    uint256 public constant ELVEN_RINGS = 3; // IDs 1-3
    uint256 public constant DWARVEN_RINGS = 7; // IDs 4-10
    uint256 public constant MORTAL_RINGS = 9; // IDs 11-19
    uint256 public constant THE_ONE_RING_ID = 20;

    // Corruption rates per 100 blocks
    uint256 public constant ELVEN_CORRUPTION_RATE = 1; // Elves resist corruption
    uint256 public constant DWARVEN_CORRUPTION_RATE = 3; // Dwarves are hardy
    uint256 public constant MORTAL_CORRUPTION_RATE = 7; // Men fall quickly
    uint256 public constant ONE_RING_CORRUPTION_RATE = 15; // The One Ring consumes all

    uint256 public constant CORRUPTION_THRESHOLD = 100;

    mapping(uint256 => Ring) public rings;
    mapping(address => BearerInfo) public bearers;
    mapping(uint256 => uint256) public ringBearerSince; // tokenId => block when current owner got it

    uint256 public ringsForged;
    bool public theOneRingDestroyed;

    address public sauron; // The Dark Lord who forges the rings

    // ─── Events ───────────────────────────────────────────────────────
    event RingForged(uint256 indexed ringId, string name, Race race, uint256 power);
    event CorruptionIncreased(address indexed bearer, uint256 newLevel);
    event BecameWraith(address indexed bearer);
    event CorruptionCleansed(address indexed bearer, uint256 amount);
    event TheOneRingDestroyed(address indexed destroyer);
    event RingDominated(uint256 indexed dominatedRingId, address indexed dominatedBearer);

    // ─── Errors ───────────────────────────────────────────────────────
    error AllRingsForged();
    error RingAlreadyForged();
    error RingNotForged();
    error RingDestroyed();
    error NotSauron();
    error BearerIsWraith();
    error NotTheOneRingBearer();
    error CannotDominateSelf();
    error TheOneRingAlreadyDestroyed();
    error NotRingBearer();
    error InvalidRingId();

    // ─── Modifiers ────────────────────────────────────────────────────
    modifier onlySauron() {
        _onlySauron();
        _;
    }

    modifier ringExists(uint256 ringId) {
        _ringExists(ringId);
        _;
    }

    modifier notWraith(address bearer) {
        _notWraith(bearer);
        _;
    }

    function _onlySauron() internal view {
        if (msg.sender != sauron) revert NotSauron();
    }

    function _ringExists(uint256 ringId) internal view {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        if (!rings[ringId].forged) revert RingNotForged();
        if (rings[ringId].destroyed) revert RingDestroyed();
    }

    function _notWraith(address bearer) internal view {
        if (bearers[bearer].isWraith) revert BearerIsWraith();
    }

    constructor() ERC721("Rings of Power", "RING") Ownable(msg.sender) {
        sauron = msg.sender;
        _initializeRings();
    }

    // ─── Ring Initialization ──────────────────────────────────────────
    function _initializeRings() internal {
        // Elven Rings
        rings[1] = Ring({
            name: "Narya - Ring of Fire", race: Race.Elven, power: 90, forged: false, destroyed: false, forgedAt: 0
        });
        rings[2] = Ring({
            name: "Nenya - Ring of Water", race: Race.Elven, power: 88, forged: false, destroyed: false, forgedAt: 0
        });
        rings[3] = Ring({
            name: "Vilya - Ring of Air", race: Race.Elven, power: 92, forged: false, destroyed: false, forgedAt: 0
        });

        // Dwarven Rings
        rings[4] =
            Ring({name: "Ring of Durin", race: Race.Dwarven, power: 75, forged: false, destroyed: false, forgedAt: 0});
        rings[5] =
            Ring({name: "Ring of Thror", race: Race.Dwarven, power: 70, forged: false, destroyed: false, forgedAt: 0});
        rings[6] = Ring({
            name: "Ring of the Iron Hills", race: Race.Dwarven, power: 65, forged: false, destroyed: false, forgedAt: 0
        });
        rings[7] = Ring({
            name: "Ring of the Blue Mountains",
            race: Race.Dwarven,
            power: 60,
            forged: false,
            destroyed: false,
            forgedAt: 0
        });
        rings[8] =
            Ring({name: "Ring of Erebor", race: Race.Dwarven, power: 72, forged: false, destroyed: false, forgedAt: 0});
        rings[9] = Ring({
            name: "Ring of Khazad-dum", race: Race.Dwarven, power: 78, forged: false, destroyed: false, forgedAt: 0
        });
        rings[10] = Ring({
            name: "Ring of the Grey Mountains",
            race: Race.Dwarven,
            power: 63,
            forged: false,
            destroyed: false,
            forgedAt: 0
        });

        // Mortal Rings (Nine for Mortal Men, doomed to die)
        rings[11] = Ring({
            name: "Ring of the Witch-king", race: Race.Mortal, power: 85, forged: false, destroyed: false, forgedAt: 0
        });
        rings[12] =
            Ring({name: "Ring of Khamul", race: Race.Mortal, power: 55, forged: false, destroyed: false, forgedAt: 0});
        rings[13] = Ring({
            name: "Ring of the Shadow", race: Race.Mortal, power: 50, forged: false, destroyed: false, forgedAt: 0
        });
        rings[14] =
            Ring({name: "Ring of Despair", race: Race.Mortal, power: 48, forged: false, destroyed: false, forgedAt: 0});
        rings[15] = Ring({
            name: "Ring of the Fallen King", race: Race.Mortal, power: 52, forged: false, destroyed: false, forgedAt: 0
        });
        rings[16] =
            Ring({name: "Ring of Dread", race: Race.Mortal, power: 47, forged: false, destroyed: false, forgedAt: 0});
        rings[17] = Ring({
            name: "Ring of the Dark Rider", race: Race.Mortal, power: 53, forged: false, destroyed: false, forgedAt: 0
        });
        rings[18] =
            Ring({name: "Ring of Ruin", race: Race.Mortal, power: 45, forged: false, destroyed: false, forgedAt: 0});
        rings[19] = Ring({
            name: "Ring of the Nazgul", race: Race.Mortal, power: 58, forged: false, destroyed: false, forgedAt: 0
        });

        // The One Ring
        rings[20] = Ring({
            name: "The One Ring", race: Race.TheOneRing, power: 100, forged: false, destroyed: false, forgedAt: 0
        });
    }

    // ─── Forging ──────────────────────────────────────────────────────

    /// @notice Sauron forges a Ring of Power and bestows it upon a bearer
    /// @param ringId The ID of the ring to forge (1-20)
    /// @param bearer The address to receive the ring
    function forge(uint256 ringId, address bearer) external onlySauron notWraith(bearer) {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        if (rings[ringId].forged) revert RingAlreadyForged();

        rings[ringId].forged = true;
        rings[ringId].forgedAt = block.number;
        ringsForged++;

        ringBearerSince[ringId] = block.number;
        _safeMint(bearer, ringId);

        emit RingForged(ringId, rings[ringId].name, rings[ringId].race, rings[ringId].power);
    }

    // ─── Corruption Mechanic ──────────────────────────────────────────

    /// @notice Calculate current corruption level for a bearer based on rings held and blocks elapsed
    /// @param bearer The address to check
    /// @return corruption The current corruption level (0-100+)
    function calculateCorruption(address bearer) public view returns (uint256 corruption) {
        corruption = bearers[bearer].corruptionLevel;

        uint256 balance = balanceOf(bearer);
        for (uint256 i = 0; i < balance; i++) {
            uint256 ringId = tokenOfOwnerByIndex(bearer, i);
            if (rings[ringId].destroyed) continue;

            uint256 blocksSince = block.number - ringBearerSince[ringId];
            uint256 rate = _getCorruptionRate(rings[ringId].race);
            corruption += (blocksSince * rate) / 100;
        }
    }

    /// @notice Update the corruption state for a bearer (anyone can call)
    /// @param bearer The address to update corruption for
    function tickCorruption(address bearer) external {
        uint256 corruption = calculateCorruption(bearer);

        // Reset base corruption and bearer-since timestamps
        bearers[bearer].corruptionLevel = corruption;
        bearers[bearer].lastCorruptionTick = block.number;

        uint256 balance = balanceOf(bearer);
        for (uint256 i = 0; i < balance; i++) {
            uint256 ringId = tokenOfOwnerByIndex(bearer, i);
            ringBearerSince[ringId] = block.number;
        }

        if (corruption >= CORRUPTION_THRESHOLD && !bearers[bearer].isWraith) {
            bearers[bearer].isWraith = true;
            emit BecameWraith(bearer);
        }

        emit CorruptionIncreased(bearer, corruption);
    }

    /// @notice Cleanse corruption from a bearer (only via MiddleEarth / owner)
    /// @param bearer The address to cleanse
    /// @param amount How much corruption to remove
    function cleanse(address bearer, uint256 amount) external onlyOwner {
        if (bearers[bearer].corruptionLevel >= amount) {
            bearers[bearer].corruptionLevel -= amount;
        } else {
            bearers[bearer].corruptionLevel = 0;
        }
        // Un-wraith if below threshold
        if (bearers[bearer].isWraith && bearers[bearer].corruptionLevel < CORRUPTION_THRESHOLD) {
            bearers[bearer].isWraith = false;
        }
        emit CorruptionCleansed(bearer, amount);
    }

    // ─── The One Ring Powers ──────────────────────────────────────────

    /// @notice The One Ring bearer can dominate other ring bearers, forcing a transfer
    /// @param targetRingId The ring to dominate
    function dominate(uint256 targetRingId) external ringExists(targetRingId) ringExists(THE_ONE_RING_ID) {
        if (ownerOf(THE_ONE_RING_ID) != msg.sender) revert NotTheOneRingBearer();
        if (targetRingId == THE_ONE_RING_ID) revert CannotDominateSelf();

        address victim = ownerOf(targetRingId);
        ringBearerSince[targetRingId] = block.number;

        _transfer(victim, msg.sender, targetRingId);
        emit RingDominated(targetRingId, victim);
    }

    /// @notice Get all ring IDs held by a bearer (visible to The One Ring holder)
    /// @param bearer The address to inspect
    /// @return ringIds Array of ring IDs
    function seeAllRings(address bearer) external view returns (uint256[] memory ringIds) {
        if (ownerOf(THE_ONE_RING_ID) != msg.sender) revert NotTheOneRingBearer();

        uint256 balance = balanceOf(bearer);
        ringIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            ringIds[i] = tokenOfOwnerByIndex(bearer, i);
        }
    }

    // ─── Destroy The One Ring ─────────────────────────────────────────

    /// @notice Cast The One Ring into Mount Doom, destroying it forever
    /// @dev Only the current bearer of The One Ring can destroy it
    function castIntoMountDoom() external ringExists(THE_ONE_RING_ID) {
        if (ownerOf(THE_ONE_RING_ID) != msg.sender) revert NotTheOneRingBearer();

        rings[THE_ONE_RING_ID].destroyed = true;
        theOneRingDestroyed = true;
        _burn(THE_ONE_RING_ID);

        // Destroying The One Ring cleanses all corruption
        bearers[msg.sender].corruptionLevel = 0;
        bearers[msg.sender].isWraith = false;

        emit TheOneRingDestroyed(msg.sender);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function getRing(uint256 ringId) external view returns (Ring memory) {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        return rings[ringId];
    }

    function getRingRace(uint256 ringId) external view returns (Race) {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        return rings[ringId].race;
    }

    function isRingForged(uint256 ringId) external view returns (bool) {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        return rings[ringId].forged;
    }

    function isBearer(address account) external view returns (bool) {
        return balanceOf(account) > 0;
    }

    function getRingPower(uint256 ringId) external view returns (uint256) {
        if (ringId == 0 || ringId > MAX_RINGS) revert InvalidRingId();
        return rings[ringId].power;
    }

    // ─── Internal ─────────────────────────────────────────────────────

    function _getCorruptionRate(Race race) internal pure returns (uint256) {
        if (race == Race.Elven) return ELVEN_CORRUPTION_RATE;
        if (race == Race.Dwarven) return DWARVEN_CORRUPTION_RATE;
        if (race == Race.Mortal) return MORTAL_CORRUPTION_RATE;
        return ONE_RING_CORRUPTION_RATE; // TheOneRing
    }

    /// @dev Update ringBearerSince on transfer
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Enumerable) returns (address) {
        address from = super._update(to, tokenId, auth);
        if (to != address(0)) {
            ringBearerSince[tokenId] = block.number;
        }
        return from;
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
