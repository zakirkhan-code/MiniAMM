// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MiniFactory.sol";
import "../src/MiniPair.sol";
import "../src/MiniRouter.sol";
import "../src/MockERC20.sol";

contract MiniRouterTest is Test {
    MiniFactory public factory;
    MiniRouter public router;

    MockERC20 public eth_;
    MockERC20 public usdc;
    MockERC20 public dai;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 1_000_000 ether;

    function setUp() public {
        // Deploy tokens
        eth_ = new MockERC20("Wrapped ETH", "WETH");
        usdc = new MockERC20("USD Coin", "USDC");
        dai = new MockERC20("DAI Stablecoin", "DAI");

        factory = new MiniFactory(address(this));
        router = new MiniRouter(address(factory));

        factory.createPair(address(eth_), address(usdc));
        factory.createPair(address(usdc), address(dai));
        factory.createPair(address(eth_), address(dai));

        eth_.mint(alice, INITIAL_BALANCE);
        usdc.mint(alice, INITIAL_BALANCE);
        dai.mint(alice, INITIAL_BALANCE);
        eth_.mint(bob, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        dai.mint(bob, INITIAL_BALANCE);

        vm.startPrank(alice);
        eth_.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        eth_.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        vm.stopPrank();

        _addInitialLiquidity(address(eth_), address(usdc), 100 ether, 200_000 ether, alice);

        _addInitialLiquidity(address(usdc), address(dai), 100_000 ether, 100_000 ether, alice);

        _addInitialLiquidity(address(eth_), address(dai), 100 ether, 200_000 ether, alice);
    }

    function _addInitialLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address user
    ) internal {
        address pairAddr = factory.getPair(tokenA, tokenB);
        MiniPair pair = MiniPair(pairAddr);

        address pairToken0 = address(pair.tokenA());

        vm.startPrank(user);
        MockERC20(tokenA).approve(address(pair), type(uint256).max);
        MockERC20(tokenB).approve(address(pair), type(uint256).max);

        if (pairToken0 == tokenA) {
            pair.addLiquidity(amountA, amountB);
        } else {
            pair.addLiquidity(amountB, amountA);
        }
        vm.stopPrank();
    }

    function test_SwapExact_Basic() public {
        uint256 bobUsdcBefore = usdc.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = router.swapExactTokensForTokens(
            1 ether,
            1900 ether,        
            address(eth_),
            address(usdc),
            bob,
            block.timestamp + 1 hours
        );

        uint256 bobUsdcAfter = usdc.balanceOf(bob);

        console.log("=== Single Swap via Router ===");
        console.log("Input: 1 WETH");
        console.log("Output USDC:", amountOut / 1e18);

        assertTrue(amountOut > 1900 ether, "Should get > 1900 USDC");
        assertTrue(amountOut < 2000 ether, "Should get < 2000 USDC");
        assertEq(bobUsdcAfter - bobUsdcBefore, amountOut, "Bob received tokens");
    }

    function test_SwapExact_SlippageReverts() public {
        vm.prank(bob);
        vm.expectRevert("MiniRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            1 ether,
            1999 ether,
            address(eth_),
            address(usdc),
            bob,
            block.timestamp + 1 hours
        );
    }

    function test_SwapExact_DeadlineReverts() public {
        vm.prank(bob);
        vm.expectRevert("MiniRouter: EXPIRED");
        router.swapExactTokensForTokens(
            1 ether,
            1900 ether,
            address(eth_),
            address(usdc),
            bob,
            block.timestamp - 1
        );
    }

    function test_SwapExact_NoPairReverts() public {
        MockERC20 randomToken = new MockERC20("Random", "RND");

        vm.prank(bob);
        vm.expectRevert("MiniRouter: PAIR_NOT_FOUND");
        router.swapExactTokensForTokens(
            1 ether,
            0,
            address(eth_),
            address(randomToken),
            bob,
            block.timestamp + 1 hours
        );
    }

    function test_MultiHop_TwoHops() public {
        uint256 bobDaiBefore = dai.balanceOf(bob);

        address[] memory path = new address[](3);
        path[0] = address(eth_);
        path[1] = address(usdc);
        path[2] = address(dai);

        vm.prank(bob);
        uint256 amountOut = router.swapExactTokensForTokensMultiHop(
            1 ether,           // 1 ETH in
            1800 ether,        // at least 1800 DAI out
            path,              // ETH -> USDC -> DAI
            bob,
            block.timestamp + 1 hours
        );

        uint256 bobDaiAfter = dai.balanceOf(bob);

        console.log("=== Multi-Hop: ETH -> USDC -> DAI ===");
        console.log("Input: 1 WETH");
        console.log("Output DAI:", amountOut / 1e18);

        assertTrue(amountOut > 1800 ether, "Should get > 1800 DAI");
        assertEq(bobDaiAfter - bobDaiBefore, amountOut, "Bob received DAI");
    }

    function test_MultiHop_SlippageReverts() public {
        address[] memory path = new address[](3);
        path[0] = address(eth_);
        path[1] = address(usdc);
        path[2] = address(dai);

        vm.prank(bob);
        vm.expectRevert("MiniRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokensMultiHop(
            1 ether,
            1999 ether,
            path,
            bob,
            block.timestamp + 1 hours
        );
    }

    function test_MultiHop_VsDirect() public {
        // Direct: ETH -> DAI (one hop)
        vm.prank(bob);
        uint256 directOut = router.swapExactTokensForTokens(
            1 ether, 0, address(eth_), address(dai), bob,
            block.timestamp + 1 hours
        );

        address[] memory path = new address[](3);
        path[0] = address(eth_);
        path[1] = address(usdc);
        path[2] = address(dai);

        vm.prank(bob);
        uint256 multiOut = router.swapExactTokensForTokensMultiHop(
            1 ether, 0, path, bob, block.timestamp + 1 hours
        );

        console.log("=== Direct vs Multi-Hop ===");
        console.log("Direct ETH->DAI:", directOut / 1e18);
        console.log("Multi ETH->USDC->DAI:", multiOut / 1e18);
        console.log("Direct wins (less fees)");

        // Direct should be better (only 1 fee vs 2 fees)
        assertTrue(directOut > multiOut, "Direct should beat multi-hop");
    }

    function test_GetAmountOut_Preview() public {
        uint256 preview = router.getAmountOut(1 ether, address(eth_), address(usdc));

        vm.prank(bob);
        uint256 actual = router.swapExactTokensForTokens(
            1 ether, 0, address(eth_), address(usdc), bob,
            block.timestamp + 1 hours
        );

        console.log("=== Preview vs Actual ===");
        console.log("Preview:", preview / 1e18);
        console.log("Actual:", actual / 1e18);

        assertEq(preview, actual, "Preview should match actual");
    }

    function test_GetAmountsOut_MultiHop() public {
        address[] memory path = new address[](3);
        path[0] = address(eth_);
        path[1] = address(usdc);
        path[2] = address(dai);

        uint256[] memory amounts = router.getAmountsOut(1 ether, path);

        console.log("=== Multi-Hop Preview ===");
        console.log("Step 0 (ETH in):", amounts[0] / 1e18);
        console.log("Step 1 (USDC):", amounts[1] / 1e18);
        console.log("Step 2 (DAI out):", amounts[2] / 1e18);

        assertEq(amounts[0], 1 ether, "First amount is input");
        assertTrue(amounts[1] > 0, "Middle hop has output");
        assertTrue(amounts[2] > 0, "Final hop has output");
        assertTrue(amounts[2] < amounts[1], "Each hop costs a fee");
    }

    function test_GetAmountsOut_InvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(eth_);

        vm.expectRevert("MiniRouter: INVALID_PATH");
        router.getAmountsOut(1 ether, path);
    }
}