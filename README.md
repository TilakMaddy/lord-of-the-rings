# The Rings of Power

**A fully on-chain Lord of the Rings game built with Solidity & Foundry.**

> *"Three Rings for the Elven-kings under the sky,*
> *Seven for the Dwarf-lords in their halls of stone,*
> *Nine for Mortal Men doomed to die,*
> *One for the Dark Lord on his dark throne.*
> *In the Land of Mordor where the Shadows lie.*
> *One Ring to rule them all, One Ring to find them,*
> *One Ring to bring them all, and in the darkness bind them."*

---

## What is this?

An interconnected system of 7 smart contracts that form a playable game set in Middle Earth. Forge rings, form fellowships, embark on quests, battle other players, mine mithril in the depths of Khazad-dum, and decide once and for all whether Arda is flat.

Built on the canonical lore that **Arda was originally flat** until Iluvatar bent the world into a sphere after the Downfall of Numenor. The Flat Earth Society of Middle Earth remembers the truth.

## Contracts

### RingsOfPower.sol - The 20 Rings of Power (ERC-721)

The core NFT contract. Sauron forges 20 rings and bestows them upon bearers.

| Ring Type | Count | IDs | Corruption Rate | Power Range |
|-----------|-------|-----|-----------------|-------------|
| Elven | 3 | 1-3 | 1 per 100 blocks | 88-92 |
| Dwarven | 7 | 4-10 | 3 per 100 blocks | 60-78 |
| Mortal | 9 | 11-19 | 7 per 100 blocks | 45-85 |
| The One Ring | 1 | 20 | 15 per 100 blocks | 100 |

**Key mechanics:**
- **Corruption** - Holding a ring corrupts you over time. At corruption level 100, you become a Wraith.
- **Domination** - The One Ring bearer can force-transfer any other ring to themselves.
- **Scrying** - The One Ring bearer can see all rings held by any address.
- **Destruction** - The One Ring can be cast into Mount Doom, destroying it forever and cleansing all corruption.

### MiddleEarth.sol - Fellowships & Quests

The adventure layer. Register as a hero, form fellowships, travel across Middle Earth, and complete quests.

**Locations:** The Shire, Rivendell, Moria, Lothlorien, Rohan, Gondor, Mordor, Mount Doom, The Undying Lands, The Void

**Features:**
- Register a hero with a title ("Strider", "Mithrandir", etc.)
- Form fellowships of up to 9 members (just like the original)
- Travel solo or move your entire fellowship
- Create and complete quests for XP rewards
- **The Mount Doom Quest** - A fellowship member must carry The One Ring to Mount Doom and destroy it. Completing this grants 10,000 XP to all fellowship members.

### Silmarillion.sol - The Light of the Two Trees (ERC-20)

The in-game currency. Named after the three jewels that captured the light of the Two Trees.

**Features:**
- **Ring Bearer Rewards** - Daily SIL rewards based on your ring's power level
- **Morgoth's Tax** - 1% tax on all transfers, collected in Morgoth's vault (just like the original dark lord, always taking his cut)
- **Feanor's Oath** - Lock your SIL tokens for boosted rewards. Longer locks = higher multipliers (100-300%). Break your oath early and lose 50%.
- 3,000,000 initial supply (one million per Silmaril)

### FlatEarthSociety.sol - The Secret Order of Arda's Flat Truth

> *"The world was flat once, and it shall be flat again."*

A conspiracy-themed staking and governance contract. In Tolkien's lore, **Arda really was flat**. The Flat Earth Society remembers.

**Ranks:**
| Rank | Belief Points Required |
|------|----------------------|
| Normie | 0 |
| Skeptic | 100 |
| Truther | 400 |
| Illuminated | 800 |
| Grand Flatmaster | 1,000 (+ manual ascension) |

**Features:**
- **Staking** - Stake ETH to prove your commitment to the flat truth. Earn belief points over time.
- **Propaganda** - Spread 8 types of flat earth propaganda. Upvote fellow truthers, downvote globe-earthers.
- **Flatness Visions** - Report visions of the flat earth for belief points. Ring bearers get double. See 10 visions to unlock "The Straight Road."
- **Unbending Rituals** - Pool ETH with other believers to "unbend" the world. Successful rituals increase the World Flatness Index.
- **Grand Flatmaster Council** - Top 5 believers govern the society. Can ban globe-earthers.
- **World Flatness Index** - A global counter from 0-100 that believers think tracks their progress in flattening Arda. (Narrator: it doesn't.)

**Propaganda Types:**
1. The World Was Flat (canonical Tolkien lore)
2. The Valar Lied About the Shape
3. Ships Disappear Because of Magic
4. The Edge Is Real
5. Numenor Knew the Truth
6. Palantiri Show a Flat Surface
7. Eagles Can See the Edge
8. Morgoth Flattens All He Creates

### Palantir.sol - The Seven Seeing Stones

Seven palantiri that allow on-chain scrying.

| Stone | Notes |
|-------|-------|
| Orthanc's Stone | Saruman's stone |
| Minas Tirith | Denethor's stone |
| Minas Ithil | Pre-corrupted by Sauron |
| Osgiliath | Lost in the river |
| Annuminas | Lost |
| Amon Sul | Lost |
| Elostirion | Looks only West - always shows "flat earth proof" |

**Features:**
- **Discovery** - Only ring bearers can find palantiri
- **Scrying Sessions** - Use a stone to receive visions about other addresses. 50-block cooldown between uses.
- **Madness** - Overuse drives you mad (like Denethor). After 10 uses, each session risks increasing your madness level. Corrupted stones (Minas Ithil) are worse.
- **The Elostirion Stone** - Always emits a `FlatEarthVision` event when used, "proving" the world is flat

### MithrilMine.sol - The Mines of Khazad-dum

Stake SIL tokens to mine mithril at five depth levels. Deeper = richer veins, but the Balrog lurks below.

| Depth | Reward Rate | Balrog Chance |
|-------|-------------|---------------|
| Surface | 1x | 0% |
| Upper Halls | 3x | 5% |
| Deep Veins | 7x | 15% |
| Moria's Deep | 15x | 30% |
| Foundation of the World | 30x | 50% |

**Features:**
- **Mining** - Stake minimum 100 SIL. Ring bearers get 50% bonus mining speed.
- **Balrog Attacks** - Checked every 200 blocks. Trapped miners lose 20% of staked SIL and can't withdraw until rescued.
- **Rescue** - Ring bearers rescue for free (like Gandalf). Others pay 50 SIL.
- **The Foundation** - Mining to the deepest level triggers a flat earth easter egg confirming the world rests on a flat foundation.

### BattleOfMiddleEarth.sol - PvP & Great Battles

A battle system with wagers, war titles, and legendary battles.

**Battle Types:**
| Type | Duration | Description |
|------|----------|-------------|
| Duel | 10 blocks | 1v1 |
| Skirmish | 25 blocks | Small fight |
| Siege | 50 blocks | Fortress assault |
| Great Battle | 100 blocks | Army vs army |

**Features:**
- **Duels** - Challenge anyone. Both sides wager SIL. Winner takes all.
- **Battle Stats** - Power calculated from XP, ring power, win history, and a random factor.
- **The One Ring** - Grants +500 power in battle.
- **War Titles** - Earned at win milestones: Warrior (5), Champion (15), Warlord (30), Conqueror (50), Legend (100).
- **5 Pre-loaded Great Battles:**
  1. Battle of the Last Alliance
  2. Battle of Helm's Deep
  3. Battle of Pelennor Fields
  4. Battle of the Black Gate
  5. Battle at the Edge of the World (Flat Earthers vs Globe Earthers)

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build

```shell
forge build
```

### Test

```shell
forge test
```

75 tests across 5 test suites covering all contracts.

### Deploy

```shell
forge script script/DeployMiddleEarth.s.sol:DeployMiddleEarth --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

The deploy script handles all 7 contracts and wires up minter permissions for the game contracts.

## Architecture

```
RingsOfPower (ERC-721)
    |
    +-- MiddleEarth (Fellowships, Quests, Mount Doom)
    |       |
    |       +-- FlatEarthSociety (Staking, Propaganda, Rituals)
    |       |
    |       +-- BattleOfMiddleEarth (PvP, Great Battles)
    |
    +-- Silmarillion (ERC-20, Rewards, Morgoth Tax, Feanor's Oath)
    |       |
    |       +-- MithrilMine (Mining, Balrog, Depth Levels)
    |
    +-- Palantir (Seeing Stones, Scrying, Madness)
```

## License

MIT
