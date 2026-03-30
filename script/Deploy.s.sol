// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MiniFactory.sol";
import "../src/MiniPair.sol";
import "../src/MiniRouter.sol";
import "../src/MockERC20.sol";

/// @title Deploy MiniAMM to Sepolia
contract DeployScript is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy test tokens
        MockERC20 weth = new MockERC20("Wrapped ETH", "WETH");
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        MockERC20 dai = new MockERC20("DAI Stablecoin", "DAI");

        console.log("WETH deployed:", address(weth));
        console.log("USDC deployed:", address(usdc));
        console.log("DAI deployed:", address(dai));

        // Step 2: Deploy Factory
        MiniFactory factory = new MiniFactory(deployer);
        console.log("Factory deployed:", address(factory));

        // Step 3: Deploy Router
        MiniRouter router = new MiniRouter(address(factory));
        console.log("Router deployed:", address(router));

        // Step 4: Create pairs
        address ethUsdcPair = factory.createPair(address(weth), address(usdc));
        address usdcDaiPair = factory.createPair(address(usdc), address(dai));
        address ethDaiPair = factory.createPair(address(weth), address(dai));

        console.log("WETH/USDC pair:", ethUsdcPair);
        console.log("USDC/DAI pair:", usdcDaiPair);
        console.log("WETH/DAI pair:", ethDaiPair);

        // Step 5: Mint test tokens to deployer
        weth.mint(deployer, 1000 ether);
        usdc.mint(deployer, 2_000_000 ether);
        dai.mint(deployer, 2_000_000 ether);

        // Step 6: Add initial liquidity to WETH/USDC pair
        MiniPair pair1 = MiniPair(ethUsdcPair);
        address pair1Token0 = address(pair1.tokenA());

        weth.approve(address(pair1), type(uint256).max);
        usdc.approve(address(pair1), type(uint256).max);

        if (pair1Token0 == address(weth)) {
            pair1.addLiquidity(100 ether, 200_000 ether);
        } else {
            pair1.addLiquidity(200_000 ether, 100 ether);
        }
        console.log("WETH/USDC liquidity added: 100 WETH + 200,000 USDC");

        // Step 7: Add initial liquidity to USDC/DAI pair
        MiniPair pair2 = MiniPair(usdcDaiPair);
        address pair2Token0 = address(pair2.tokenA());

        usdc.approve(address(pair2), type(uint256).max);
        dai.approve(address(pair2), type(uint256).max);

        if (pair2Token0 == address(usdc)) {
            pair2.addLiquidity(100_000 ether, 100_000 ether);
        } else {
            pair2.addLiquidity(100_000 ether, 100_000 ether);
        }
        console.log("USDC/DAI liquidity added: 100,000 USDC + 100,000 DAI");

        // Step 8: Add initial liquidity to WETH/DAI pair
        MiniPair pair3 = MiniPair(ethDaiPair);
        address pair3Token0 = address(pair3.tokenA());

        weth.approve(address(pair3), type(uint256).max);
        dai.approve(address(pair3), type(uint256).max);

        if (pair3Token0 == address(weth)) {
            pair3.addLiquidity(100 ether, 200_000 ether);
        } else {
            pair3.addLiquidity(200_000 ether, 100 ether);
        }
        console.log("WETH/DAI liquidity added: 100 WETH + 200,000 DAI");

        vm.stopBroadcast();

        // Summary
        console.log("");
        console.log("========== DEPLOYMENT COMPLETE ==========");
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("WETH:", address(weth));
        console.log("USDC:", address(usdc));
        console.log("DAI:", address(dai));
        console.log("WETH/USDC Pair:", ethUsdcPair);
        console.log("USDC/DAI Pair:", usdcDaiPair);
        console.log("WETH/DAI Pair:", ethDaiPair);
        console.log("=========================================");
    }
}
