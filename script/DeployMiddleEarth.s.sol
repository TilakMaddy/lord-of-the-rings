// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RingsOfPower} from "../src/RingsOfPower.sol";
import {MiddleEarth} from "../src/MiddleEarth.sol";
import {Silmarillion} from "../src/Silmarillion.sol";
import {FlatEarthSociety} from "../src/FlatEarthSociety.sol";
import {Palantir} from "../src/Palantir.sol";
import {MithrilMine} from "../src/MithrilMine.sol";
import {BattleOfMiddleEarth} from "../src/BattleOfMiddleEarth.sol";

/// @title DeployMiddleEarth - Deploy all contracts for the Lord of the Rings ecosystem
contract DeployMiddleEarth is Script {
    function run() public {
        vm.startBroadcast();

        // 1. Deploy core NFT contract
        RingsOfPower rings = new RingsOfPower();
        console.log("RingsOfPower deployed at:", address(rings));

        // 2. Deploy MiddleEarth (fellowship & quests)
        MiddleEarth middleEarth = new MiddleEarth(address(rings));
        console.log("MiddleEarth deployed at:", address(middleEarth));

        // 3. Deploy SIL token
        Silmarillion sil = new Silmarillion(address(rings));
        console.log("Silmarillion (SIL) deployed at:", address(sil));

        // 4. Deploy Flat Earth Society
        FlatEarthSociety flatEarth = new FlatEarthSociety(address(rings), address(middleEarth));
        console.log("FlatEarthSociety deployed at:", address(flatEarth));

        // 5. Deploy Palantir
        Palantir palantir = new Palantir(address(rings));
        console.log("Palantir deployed at:", address(palantir));

        // 6. Deploy MithrilMine
        MithrilMine mine = new MithrilMine(address(sil), address(rings));
        console.log("MithrilMine deployed at:", address(mine));

        // 7. Deploy Battle system
        BattleOfMiddleEarth battle = new BattleOfMiddleEarth(address(rings), address(middleEarth), address(sil));
        console.log("BattleOfMiddleEarth deployed at:", address(battle));

        // 8. Authorize game contracts as SIL minters
        sil.authorizeMinter(address(mine));
        sil.authorizeMinter(address(battle));
        console.log("Authorized MithrilMine and Battle as SIL minters");

        vm.stopBroadcast();

        console.log("\n=== The Rings of Power: Deployment Complete ===");
        console.log("Total contracts deployed: 7");
    }
}
