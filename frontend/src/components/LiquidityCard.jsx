import { useState, useEffect } from "react";
import { ethers } from "ethers";
import { ADDRESSES } from "../config";
import FactoryABI from "../abi/MiniFactory.json";
import PairABI from "../abi/MiniPair.json";
import ERC20ABI from "../abi/MockERC20.json";

const tokens = Object.values(ADDRESSES.tokens);

function LiquidityCard({ provider, signer, account }) {
  const [mode, setMode] = useState("add"); // "add" or "remove"
  const [tokenA, setTokenA] = useState(tokens[0]);
  const [tokenB, setTokenB] = useState(tokens[1]);
  const [amountA, setAmountA] = useState("");
  const [amountB, setAmountB] = useState("");
  const [balanceA, setBalanceA] = useState("0");
  const [balanceB, setBalanceB] = useState("0");
  const [lpBalance, setLpBalance] = useState("0");
  const [lpAmount, setLpAmount] = useState("");
  const [removeAmountA, setRemoveAmountA] = useState("0");
  const [removeAmountB, setRemoveAmountB] = useState("0");
  const [pairAddress, setPairAddress] = useState(null);
  const [reserveA, setReserveA] = useState("0");
  const [reserveB, setReserveB] = useState("0");
  const [poolShare, setPoolShare] = useState("0");
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState(null);
  const [error, setError] = useState("");

  // Fetch pair info
  useEffect(() => {
    if (!provider) return;

    const fetchPairInfo = async () => {
      try {
        const factory = new ethers.Contract(ADDRESSES.factory, FactoryABI, provider);
        const pairAddr = await factory.getPair(tokenA.address, tokenB.address);

        if (pairAddr === ethers.ZeroAddress) {
          setPairAddress(null);
          return;
        }

        setPairAddress(pairAddr);
        const pair = new ethers.Contract(pairAddr, PairABI, provider);

        const [resA, resB] = await pair.getReserves();
        const pairToken0 = await pair.tokenA();

        // Map reserves to match our tokenA/tokenB order
        if (pairToken0.toLowerCase() === tokenA.address.toLowerCase()) {
          setReserveA(ethers.formatEther(resA));
          setReserveB(ethers.formatEther(resB));
        } else {
          setReserveA(ethers.formatEther(resB));
          setReserveB(ethers.formatEther(resA));
        }

        // Fetch balances
        if (account) {
          const tokenAContract = new ethers.Contract(tokenA.address, ERC20ABI, provider);
          const tokenBContract = new ethers.Contract(tokenB.address, ERC20ABI, provider);

          const balA = await tokenAContract.balanceOf(account);
          const balB = await tokenBContract.balanceOf(account);
          const lpBal = await pair.balanceOf(account);
          const totalSupply = await pair.totalSupply();

          setBalanceA(ethers.formatEther(balA));
          setBalanceB(ethers.formatEther(balB));
          setLpBalance(ethers.formatEther(lpBal));

          if (totalSupply > 0n && lpBal > 0n) {
            const share = (lpBal * 10000n) / totalSupply;
            setPoolShare((Number(share) / 100).toFixed(2));
          } else {
            setPoolShare("0");
          }
        }
      } catch (err) {
        console.error("Pair info error:", err);
      }
    };

    fetchPairInfo();
  }, [provider, account, tokenA, tokenB, txHash]);

  // Calculate amountB when amountA changes (proportional)
  useEffect(() => {
    if (!amountA || parseFloat(amountA) <= 0 || parseFloat(reserveA) === 0) {
      setAmountB("");
      return;
    }

    const rA = parseFloat(reserveA);
    const rB = parseFloat(reserveB);

    if (rA > 0 && rB > 0) {
      const optimalB = (parseFloat(amountA) * rB) / rA;
      setAmountB(optimalB.toFixed(6));
    }
  }, [amountA, reserveA, reserveB]);

  // Calculate remove amounts
  useEffect(() => {
    if (!lpAmount || parseFloat(lpAmount) <= 0 || parseFloat(lpBalance) === 0) {
      setRemoveAmountA("0");
      setRemoveAmountB("0");
      return;
    }

    const share = parseFloat(lpAmount) / (parseFloat(lpBalance) + parseFloat(lpAmount));
    // Approximate - actual amount depends on totalSupply
    const rA = parseFloat(reserveA);
    const rB = parseFloat(reserveB);

    if (rA > 0 && rB > 0 && parseFloat(lpBalance) > 0) {
      // Simple proportion: your LP / total LP * reserves
      const fraction = parseFloat(lpAmount) / parseFloat(lpBalance);
      setRemoveAmountA((rA * fraction * parseFloat(poolShare) / 100).toFixed(6));
      setRemoveAmountB((rB * fraction * parseFloat(poolShare) / 100).toFixed(6));
    }
  }, [lpAmount, lpBalance, reserveA, reserveB, poolShare]);

  // Add liquidity
  const handleAddLiquidity = async () => {
    if (!signer || !amountA || !amountB || !pairAddress) return;

    setLoading(true);
    setError("");
    setTxHash(null);

    try {
      const pair = new ethers.Contract(pairAddress, PairABI, signer);
      const tokenAContract = new ethers.Contract(tokenA.address, ERC20ABI, signer);
      const tokenBContract = new ethers.Contract(tokenB.address, ERC20ABI, signer);

      const amtA = ethers.parseEther(amountA);
      const amtB = ethers.parseEther(amountB);

      // Approve pair
      const allowanceA = await tokenAContract.allowance(account, pairAddress);
      if (allowanceA < amtA) {
        const tx = await tokenAContract.approve(pairAddress, ethers.MaxUint256);
        await tx.wait();
      }

      const allowanceB = await tokenBContract.allowance(account, pairAddress);
      if (allowanceB < amtB) {
        const tx = await tokenBContract.approve(pairAddress, ethers.MaxUint256);
        await tx.wait();
      }

      // Determine correct order for pair
      const pairToken0 = await pair.tokenA();
      let tx;
      if (pairToken0.toLowerCase() === tokenA.address.toLowerCase()) {
        tx = await pair.addLiquidity(amtA, amtB);
      } else {
        tx = await pair.addLiquidity(amtB, amtA);
      }

      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      setAmountA("");
      setAmountB("");
    } catch (err) {
      console.error("Add liquidity failed:", err);
      setError(err.reason || "Add liquidity failed");
    } finally {
      setLoading(false);
    }
  };

  // Remove liquidity
  const handleRemoveLiquidity = async () => {
    if (!signer || !lpAmount || !pairAddress) return;

    setLoading(true);
    setError("");
    setTxHash(null);

    try {
      const pair = new ethers.Contract(pairAddress, PairABI, signer);
      const lpAmtWei = ethers.parseEther(lpAmount);

      const tx = await pair.removeLiquidity(lpAmtWei);
      const receipt = await tx.wait();

      setTxHash(receipt.hash);
      setLpAmount("");
    } catch (err) {
      console.error("Remove liquidity failed:", err);
      setError(err.reason || "Remove liquidity failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="swap-card">
      {/* Mode toggle */}
      <div className="mode-toggle">
        <button
          className={`mode-btn ${mode === "add" ? "active" : ""}`}
          onClick={() => { setMode("add"); setError(""); setTxHash(null); }}
        >
          Add Liquidity
        </button>
        <button
          className={`mode-btn ${mode === "remove" ? "active" : ""}`}
          onClick={() => { setMode("remove"); setError(""); setTxHash(null); }}
        >
          Remove Liquidity
        </button>
      </div>

      {mode === "add" ? (
        <>
          {/* Token A input */}
          <div className="token-input-box">
            <div className="token-input-header">
              <span className="label">Token A</span>
              <span className="balance" onClick={() => setAmountA(balanceA)}>
                Balance: {parseFloat(balanceA).toFixed(4)}
              </span>
            </div>
            <div className="token-input-row">
              <input
                type="number"
                placeholder="0.0"
                value={amountA}
                onChange={(e) => setAmountA(e.target.value)}
                className="amount-input"
              />
              <select
                value={tokenA.symbol}
                onChange={(e) => {
                  const token = tokens.find((t) => t.symbol === e.target.value);
                  if (token.symbol === tokenB.symbol) {
                    setTokenB(tokenA);
                  }
                  setTokenA(token);
                  setAmountA("");
                  setAmountB("");
                }}
                className="token-select"
              >
                {tokens.map((t) => (
                  <option key={t.symbol} value={t.symbol}>{t.symbol}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="plus-container">
            <span className="plus-icon">+</span>
          </div>

          {/* Token B input */}
          <div className="token-input-box">
            <div className="token-input-header">
              <span className="label">Token B (auto-calculated)</span>
              <span className="balance">
                Balance: {parseFloat(balanceB).toFixed(4)}
              </span>
            </div>
            <div className="token-input-row">
              <input
                type="number"
                placeholder="0.0"
                value={amountB}
                readOnly
                className="amount-input"
              />
              <select
                value={tokenB.symbol}
                onChange={(e) => {
                  const token = tokens.find((t) => t.symbol === e.target.value);
                  if (token.symbol === tokenA.symbol) {
                    setTokenA(tokenB);
                  }
                  setTokenB(token);
                  setAmountA("");
                  setAmountB("");
                }}
                className="token-select"
              >
                {tokens.map((t) => (
                  <option key={t.symbol} value={t.symbol}>{t.symbol}</option>
                ))}
              </select>
            </div>
          </div>
        </>
      ) : (
        <>
          {/* Remove mode: Token selection */}
          <div className="token-pair-select">
            <div className="token-input-box">
              <div className="token-input-header">
                <span className="label">Select pair</span>
              </div>
              <div className="token-input-row">
                <select
                  value={tokenA.symbol}
                  onChange={(e) => {
                    const token = tokens.find((t) => t.symbol === e.target.value);
                    if (token.symbol === tokenB.symbol) setTokenB(tokenA);
                    setTokenA(token);
                  }}
                  className="token-select"
                  style={{ flex: 1 }}
                >
                  {tokens.map((t) => (
                    <option key={t.symbol} value={t.symbol}>{t.symbol}</option>
                  ))}
                </select>
                <span style={{ color: "#8b949e", fontSize: "18px" }}>/</span>
                <select
                  value={tokenB.symbol}
                  onChange={(e) => {
                    const token = tokens.find((t) => t.symbol === e.target.value);
                    if (token.symbol === tokenA.symbol) setTokenA(tokenB);
                    setTokenB(token);
                  }}
                  className="token-select"
                  style={{ flex: 1 }}
                >
                  {tokens.map((t) => (
                    <option key={t.symbol} value={t.symbol}>{t.symbol}</option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {/* LP token amount */}
          <div className="token-input-box" style={{ marginTop: "8px" }}>
            <div className="token-input-header">
              <span className="label">LP tokens to remove</span>
              <span className="balance" onClick={() => setLpAmount(lpBalance)}>
                Your LP: {parseFloat(lpBalance).toFixed(6)}
              </span>
            </div>
            <div className="token-input-row">
              <input
                type="number"
                placeholder="0.0"
                value={lpAmount}
                onChange={(e) => setLpAmount(e.target.value)}
                className="amount-input"
              />
              <span className="token-badge">LP</span>
            </div>
          </div>

          {/* Quick percentages */}
          {parseFloat(lpBalance) > 0 && (
            <div className="quick-amounts">
              {[25, 50, 75, 100].map((pct) => (
                <button
                  key={pct}
                  className="quick-btn"
                  onClick={() => setLpAmount((parseFloat(lpBalance) * pct / 100).toString())}
                >
                  {pct}%
                </button>
              ))}
            </div>
          )}
        </>
      )}

      {/* Pool info */}
      {pairAddress && (
        <div className="swap-details" style={{ marginTop: "12px" }}>
          <div className="detail-row">
            <span>Pool</span>
            <span>{tokenA.symbol}/{tokenB.symbol}</span>
          </div>
          <div className="detail-row">
            <span>{tokenA.symbol} reserve</span>
            <span>{parseFloat(reserveA).toFixed(4)}</span>
          </div>
          <div className="detail-row">
            <span>{tokenB.symbol} reserve</span>
            <span>{parseFloat(reserveB).toFixed(4)}</span>
          </div>
          <div className="detail-row">
            <span>Your pool share</span>
            <span>{poolShare}%</span>
          </div>
          <div className="detail-row">
            <span>Your LP tokens</span>
            <span>{parseFloat(lpBalance).toFixed(6)}</span>
          </div>
        </div>
      )}

      {!pairAddress && (
        <div className="error-msg" style={{ marginTop: "12px" }}>
          No pair found for {tokenA.symbol}/{tokenB.symbol}
        </div>
      )}

      {error && <div className="error-msg">{error}</div>}

      {txHash && (
        <div className="success-msg">
          {mode === "add" ? "Liquidity added!" : "Liquidity removed!"}{" "}
          <a href={`https://sepolia.etherscan.io/tx/${txHash}`} target="_blank" rel="noreferrer">
            View on Etherscan
          </a>
        </div>
      )}

      {/* Action button */}
      <button
        className="swap-btn"
        onClick={mode === "add" ? handleAddLiquidity : handleRemoveLiquidity}
        disabled={
          !account || loading ||
          (mode === "add" ? (!amountA || !amountB) : !lpAmount)
        }
      >
        {!account
          ? "Connect Wallet"
          : loading
          ? (mode === "add" ? "Adding..." : "Removing...")
          : mode === "add"
          ? `Add ${tokenA.symbol} + ${tokenB.symbol} Liquidity`
          : `Remove Liquidity`}
      </button>
    </div>
  );
}

export default LiquidityCard;