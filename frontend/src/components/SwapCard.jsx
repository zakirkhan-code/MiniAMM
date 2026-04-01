import { useState, useEffect } from "react";
import { ethers } from "ethers";
import { ADDRESSES } from "../config";
import RouterABI from "../abi/MiniRouter.json";
import ERC20ABI from "../abi/MockERC20.json";

const tokens = Object.values(ADDRESSES.tokens);

function SwapCard({ provider, signer, account }) {
  const [tokenIn, setTokenIn] = useState(tokens[0]);
  const [tokenOut, setTokenOut] = useState(tokens[1]);
  const [amountIn, setAmountIn] = useState("");
  const [amountOut, setAmountOut] = useState("");
  const [balanceIn, setBalanceIn] = useState("0");
  const [balanceOut, setBalanceOut] = useState("0");
  const [slippage, setSlippage] = useState("1");
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState(null);
  const [error, setError] = useState("");

  // Fetch balances
  useEffect(() => {
    if (!provider || !account) return;

    const fetchBalances = async () => {
      try {
        const contractIn = new ethers.Contract(tokenIn.address, ERC20ABI, provider);
        const contractOut = new ethers.Contract(tokenOut.address, ERC20ABI, provider);

        const balIn = await contractIn.balanceOf(account);
        const balOut = await contractOut.balanceOf(account);

        setBalanceIn(ethers.formatEther(balIn));
        setBalanceOut(ethers.formatEther(balOut));
      } catch (err) {
        console.error("Balance fetch error:", err);
      }
    };

    fetchBalances();
  }, [provider, account, tokenIn, tokenOut, txHash]);

  // Get quote when amountIn changes
  useEffect(() => {
    if (!provider || !amountIn || parseFloat(amountIn) <= 0) {
      setAmountOut("");
      return;
    }

    const getQuote = async () => {
      try {
        setError("");
        const router = new ethers.Contract(ADDRESSES.router, RouterABI, provider);
        const amountInWei = ethers.parseEther(amountIn);

        const quote = await router.getAmountOut(
          amountInWei,
          tokenIn.address,
          tokenOut.address
        );

        setAmountOut(ethers.formatEther(quote));
      } catch (err) {
        console.error("Quote error:", err);
        setAmountOut("");
        setError("No pair found for this route");
      }
    };

    const timer = setTimeout(getQuote, 300);
    return () => clearTimeout(timer);
  }, [provider, amountIn, tokenIn, tokenOut]);

  // Swap tokens position
  const handleFlip = () => {
    setTokenIn(tokenOut);
    setTokenOut(tokenIn);
    setAmountIn(amountOut);
    setAmountOut("");
  };

  // Execute swap
  const handleSwap = async () => {
    if (!signer || !amountIn) return;

    setLoading(true);
    setError("");
    setTxHash(null);

    try {
      const router = new ethers.Contract(ADDRESSES.router, RouterABI, signer);
      const tokenContract = new ethers.Contract(tokenIn.address, ERC20ABI, signer);

      const amountInWei = ethers.parseEther(amountIn);

      // Calculate minimum output with slippage
      const expectedOut = ethers.parseEther(amountOut);
      const slippageBps = BigInt(Math.floor(parseFloat(slippage) * 100));
      const amountOutMin = expectedOut - (expectedOut * slippageBps) / 10000n;

      // Deadline: 20 minutes from now
      const deadline = Math.floor(Date.now() / 1000) + 20 * 60;

      // Step 1: Approve Router
      const allowance = await tokenContract.allowance(account, ADDRESSES.router);
      if (allowance < amountInWei) {
        const approveTx = await tokenContract.approve(ADDRESSES.router, ethers.MaxUint256);
        await approveTx.wait();
      }

      // Step 2: Execute swap
      const tx = await router.swapExactTokensForTokens(
        amountInWei,
        amountOutMin,
        tokenIn.address,
        tokenOut.address,
        account,
        deadline
      );

      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      setAmountIn("");
      setAmountOut("");
    } catch (err) {
      console.error("Swap failed:", err);
      if (err.reason) {
        setError(err.reason);
      } else if (err.message.includes("user rejected")) {
        setError("Transaction rejected by user");
      } else {
        setError("Swap failed. Check console for details.");
      }
    } finally {
      setLoading(false);
    }
  };

  // Calculate price impact
  const priceImpact = amountIn && amountOut && parseFloat(amountIn) > 0
    ? (() => {
        const rate = parseFloat(amountOut) / parseFloat(amountIn);
        // Rough spot price from small amount
        return null; // Will show after we have spot price
      })()
    : null;

  const minReceived = amountOut
    ? (parseFloat(amountOut) * (1 - parseFloat(slippage) / 100)).toFixed(4)
    : "0";

  return (
    <div className="swap-card">
      <div className="swap-header">
        <h2>Swap</h2>
        <div className="slippage-setting">
          <span>Slippage:</span>
          <input
            type="number"
            value={slippage}
            onChange={(e) => setSlippage(e.target.value)}
            min="0.1"
            max="50"
            step="0.1"
          />
          <span>%</span>
        </div>
      </div>

      {/* Token In */}
      <div className="token-input-box">
        <div className="token-input-header">
          <span className="label">You pay</span>
          <span className="balance" onClick={() => setAmountIn(balanceIn)}>
            Balance: {parseFloat(balanceIn).toFixed(4)}
          </span>
        </div>
        <div className="token-input-row">
          <input
            type="number"
            placeholder="0.0"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
            className="amount-input"
          />
          <select
            value={tokenIn.symbol}
            onChange={(e) => {
              const token = tokens.find((t) => t.symbol === e.target.value);
              if (token.symbol === tokenOut.symbol) handleFlip();
              else setTokenIn(token);
            }}
            className="token-select"
          >
            {tokens.map((t) => (
              <option key={t.symbol} value={t.symbol}>
                {t.symbol}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Flip button */}
      <div className="flip-container">
        <button className="flip-btn" onClick={handleFlip}>
          ↕
        </button>
      </div>

      {/* Token Out */}
      <div className="token-input-box">
        <div className="token-input-header">
          <span className="label">You receive</span>
          <span className="balance">
            Balance: {parseFloat(balanceOut).toFixed(4)}
          </span>
        </div>
        <div className="token-input-row">
          <input
            type="number"
            placeholder="0.0"
            value={amountOut}
            readOnly
            className="amount-input"
          />
          <select
            value={tokenOut.symbol}
            onChange={(e) => {
              const token = tokens.find((t) => t.symbol === e.target.value);
              if (token.symbol === tokenIn.symbol) handleFlip();
              else setTokenOut(token);
            }}
            className="token-select"
          >
            {tokens.map((t) => (
              <option key={t.symbol} value={t.symbol}>
                {t.symbol}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Swap details */}
      {amountOut && (
        <div className="swap-details">
          <div className="detail-row">
            <span>Rate</span>
            <span>
              1 {tokenIn.symbol} = {(parseFloat(amountOut) / parseFloat(amountIn)).toFixed(4)}{" "}
              {tokenOut.symbol}
            </span>
          </div>
          <div className="detail-row">
            <span>Minimum received</span>
            <span>
              {minReceived} {tokenOut.symbol}
            </span>
          </div>
          <div className="detail-row">
            <span>Slippage tolerance</span>
            <span>{slippage}%</span>
          </div>
          <div className="detail-row">
            <span>Fee</span>
            <span>0.3%</span>
          </div>
        </div>
      )}

      {/* Error */}
      {error && <div className="error-msg">{error}</div>}

      {/* Success */}
      {txHash && (
        <div className="success-msg">
          Swap successful!{" "}
          
            <a href={`https://sepolia.etherscan.io/tx/${txHash}`}
            target="_blank"
            rel="noreferrer"
          >
            View on Etherscan
          </a>
        </div>
      )}

      {/* Swap button */}
      <button
        className="swap-btn"
        onClick={handleSwap}
        disabled={!account || !amountIn || !amountOut || loading}
      >
        {!account
          ? "Connect Wallet"
          : loading
          ? "Swapping..."
          : !amountIn
          ? "Enter amount"
          : error
          ? "Swap not available"
          : `Swap ${tokenIn.symbol} for ${tokenOut.symbol}`}
      </button>
    </div>
  );
}

export default SwapCard;