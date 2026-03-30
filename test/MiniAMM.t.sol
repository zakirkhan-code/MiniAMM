// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MiniFactory.sol";
import "../src/MiniPair.sol";
import "../src/MockERC20.sol";

contract MiniAMMTest is Test {
    MiniFactory public factory;
    MiniPair public pair;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public tokenC;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_BALANCE = 1_000_000 ether;

    function setUp() public {

        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        tokenC = new MockERC20("Token C", "TKC");

        factory = new MiniFactory(address(this));

        address pairAddr = factory.createPair(address(tokenA), address(tokenB));
        pair = MiniPair(pairAddr);

        tokenA.mint(alice, INITIAL_BALANCE);
        tokenB.mint(alice, INITIAL_BALANCE);
        tokenA.mint(bob, INITIAL_BALANCE);
        tokenB.mint(bob, INITIAL_BALANCE);
        tokenA.mint(charlie, INITIAL_BALANCE);
        tokenB.mint(charlie, INITIAL_BALANCE);

        // Approve pair for all users
        vm.prank(alice);
        tokenA.approve(address(pair), type(uint256).max);
        vm.prank(alice);
        tokenB.approve(address(pair), type(uint256).max);

        vm.prank(bob);
        tokenA.approve(address(pair), type(uint256).max);
        vm.prank(bob);
        tokenB.approve(address(pair), type(uint256).max);

        vm.prank(charlie);
        tokenA.approve(address(pair), type(uint256).max);
        vm.prank(charlie);
        tokenB.approve(address(pair), type(uint256).max);
    }

    function test_Factory_CreatePair() public {
        address pairAddr = factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pairAddr != address(0), "Pair should exist");
        assertEq(factory.allPairsLength(), 1, "Should have 1 pair");

        console.log("=== Factory Create Pair ===");
        console.log("Pair address:", pairAddr);
    }

    function test_Factory_BidirectionalLookup() public {
        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        address pairBA = factory.getPair(address(tokenB), address(tokenA));
        assertEq(pairAB, pairBA, "Lookup should work both ways");
    }

    function test_Factory_RevertDuplicate() public {
        vm.expectRevert("MiniFactory: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
    }

    function test_Factory_RevertIdentical() public {
        vm.expectRevert("MiniFactory: IDENTICAL_ADDRESSES");
        factory.createPair(address(tokenA), address(tokenA));
    }

    function test_Factory_MultiplePairs() public {
        // Mint tokenC
        tokenC.mint(alice, INITIAL_BALANCE);

        address pair2Addr = factory.createPair(address(tokenA), address(tokenC));

        address pair3Addr = factory.createPair(address(tokenB), address(tokenC));

        assertEq(factory.allPairsLength(), 3, "Should have 3 pairs");
        assertTrue(pair2Addr != address(pair), "Pairs should be different");
        assertTrue(pair3Addr != pair2Addr, "All pairs unique");

        console.log("=== Multiple Pairs ===");
        console.log("TKA/TKB:", address(pair));
        console.log("TKA/TKC:", pair2Addr);
        console.log("TKB/TKC:", pair3Addr);
    }

    function test_Pair_CannotReinitialize() public {
        vm.expectRevert("MiniPair: FORBIDDEN");
        pair.initialize(address(tokenA), address(tokenB));
    }

    function test_AddLiquidity_FirstDeposit() public {
        uint256 amountA = 100 ether;
        uint256 amountB = 200 ether;

        vm.prank(alice);
        uint256 liquidity = pair.addLiquidity(amountA, amountB);

        uint256 expectedSqrt = _sqrt(amountA * amountB);
        uint256 expectedLiquidity = expectedSqrt - 1000;

        assertEq(liquidity, expectedLiquidity, "First deposit liquidity mismatch");
        assertEq(pair.reserveA(), amountA, "ReserveA mismatch");
        assertEq(pair.reserveB(), amountB, "ReserveB mismatch");
        assertEq(pair.balanceOf(address(0)), 1000, "Minimum liquidity not locked");

        console.log("=== First Liquidity Deposit ===");
        console.log("LP tokens minted:", liquidity);
    }

    function test_Swap_AtoB() public {

        address pairTokenA = address(pair.tokenA());
        address pairTokenB = address(pair.tokenB());

        vm.prank(alice);
        pair.addLiquidity(100 ether, 200_000 ether);

        uint256 resA = pair.reserveA();
        uint256 resB = pair.reserveB();

        address swapIn;
        if (resA == 100 ether) {
            swapIn = pairTokenA;
        } else {
            swapIn = pairTokenB;
        }

        uint256 bobBalanceBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = pair.swap(swapIn, 1 ether);

        console.log("=== Swap: 1 token -> other ===");
        console.log("Output:", amountOut / 1e18);

        assertTrue(amountOut < 2000 ether, "Should be less than spot price");
        assertTrue(amountOut > 1900 ether, "Should be reasonable");
    }

    function test_Swap_KOnlyIncreases() public {
        vm.prank(alice);
        pair.addLiquidity(100 ether, 200_000 ether);

        uint256 kBefore = pair.reserveA() * pair.reserveB();

        vm.startPrank(bob);
        pair.swap(address(tokenA), 5 ether);
        pair.swap(address(tokenB), 10_000 ether);
        pair.swap(address(tokenA), 2 ether);
        vm.stopPrank();

        uint256 kAfter = pair.reserveA() * pair.reserveB();

        console.log("=== K Invariant Check ===");
        console.log("K before:", kBefore);
        console.log("K after:", kAfter);

        assertTrue(kAfter >= kBefore, "K should never decrease");
    }

    /// @notice Test: Price impact
    function test_Swap_PriceImpact() public {
        vm.prank(alice);
        pair.addLiquidity(100 ether, 200_000 ether);

        uint256 smallOut = pair.getAmountOut(0.1 ether, 100 ether, 200_000 ether);
        uint256 largeOut = pair.getAmountOut(10 ether, 100 ether, 200_000 ether);

        uint256 smallPrice = (smallOut * 1e18) / 0.1 ether;
        uint256 largePrice = (largeOut * 1e18) / 10 ether;

        console.log("=== Price Impact ===");
        console.log("Small swap price per TKA:", smallPrice / 1e18);
        console.log("Large swap price per TKA:", largePrice / 1e18);

        assertTrue(smallPrice > largePrice, "Larger swaps should get worse price");
    }

    /// @notice Test: LP earns fees
    function test_LP_EarnsFees() public {
        vm.prank(alice);
        uint256 liquidity = pair.addLiquidity(100 ether, 200_000 ether);

        vm.startPrank(bob);
        for (uint i = 0; i < 10; i++) {
            pair.swap(address(tokenA), 5 ether);
            pair.swap(address(tokenB), 10_000 ether);
        }
        vm.stopPrank();

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = pair.removeLiquidity(liquidity);

        uint256 kFinal = amountA * amountB;
        uint256 kInitial = uint256(100 ether) * uint256(200_000 ether);

        console.log("=== LP Fee Earnings ===");
        console.log("Withdrew TKA:", amountA / 1e18);
        console.log("Withdrew TKB:", amountB / 1e18);

        assertTrue(kFinal >= kInitial, "LP should earn fees");
    }

    /// @notice Test: Revert cases
    function test_Revert_SwapZeroAmount() public {
        vm.prank(alice);
        pair.addLiquidity(100 ether, 200 ether);

        vm.prank(bob);
        vm.expectRevert("MiniPair: INSUFFICIENT_INPUT");
        pair.swap(address(tokenA), 0);
    }

    function test_Revert_SwapInvalidToken() public {
        vm.prank(alice);
        pair.addLiquidity(100 ether, 200 ether);

        vm.prank(bob);
        vm.expectRevert("MiniPair: INVALID_TOKEN");
        pair.swap(address(0x1234), 1 ether);
    }

    /// @notice Test: Price view
    function test_GetPrice() public {
        vm.prank(alice);
        pair.addLiquidity(100 ether, 200_000 ether);

        uint256 priceA = pair.getPriceA();
        console.log("=== Price ===");
        console.log("1 TKA =", priceA / 1e18, "TKB");

        assertEq(priceA / 1e18, 2000, "TKA price should be 2000 TKB");
    }

    // ========== HELPER ==========
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}