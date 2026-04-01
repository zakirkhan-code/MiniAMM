import { useState, useEffect } from "react";
import { BrowserRouter, Routes, Route, NavLink } from "react-router-dom";
import { ethers } from "ethers";
import { ADDRESSES, CHAIN_ID, CHAIN_NAME } from "./config";
import Header from "./components/Header";
import SwapCard from "./components/SwapCard";
import LiquidityCard from "./components/LiquidityCard";
import "./styles.css";

function App() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [chainId, setChainId] = useState(null);

  const connectWallet = async () => {
    if (!window.ethereum) {
      alert("MetaMask install karo!");
      return;
    }
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const accounts = await provider.send("eth_requestAccounts", []);
      const signer = await provider.getSigner();
      const network = await provider.getNetwork();

      setProvider(provider);
      setSigner(signer);
      setAccount(accounts[0]);
      setChainId(Number(network.chainId));

      if (Number(network.chainId) !== CHAIN_ID) {
        try {
          await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: "0x" + CHAIN_ID.toString(16) }],
          });
        } catch (err) {
          alert("Please switch to Sepolia network!");
        }
      }
    } catch (err) {
      console.error("Connection failed:", err);
    }
  };

  useEffect(() => {
    if (!window.ethereum) return;
    const handleAccountsChanged = (accounts) => {
      if (accounts.length === 0) {
        setAccount(null);
        setSigner(null);
      } else {
        setAccount(accounts[0]);
        connectWallet();
      }
    };
    const handleChainChanged = () => window.location.reload();

    window.ethereum.on("accountsChanged", handleAccountsChanged);
    window.ethereum.on("chainChanged", handleChainChanged);
    return () => {
      window.ethereum.removeListener("accountsChanged", handleAccountsChanged);
      window.ethereum.removeListener("chainChanged", handleChainChanged);
    };
  }, []);

  useEffect(() => {
    if (window.ethereum) {
      window.ethereum
        .request({ method: "eth_accounts" })
        .then((accounts) => {
          if (accounts.length > 0) connectWallet();
        });
    }
  }, []);

  const isWrongNetwork = chainId && chainId !== CHAIN_ID;

  return (
    <BrowserRouter>
      <div className="app">
        <Header
          account={account}
          chainId={chainId}
          isWrongNetwork={isWrongNetwork}
          onConnect={connectWallet}
        />

        {/* Navigation tabs */}
        <nav className="nav-tabs">
          <NavLink to="/" className={({ isActive }) => isActive ? "tab active" : "tab"} end>
            Swap
          </NavLink>
          <NavLink to="/liquidity" className={({ isActive }) => isActive ? "tab active" : "tab"}>
            Liquidity
          </NavLink>
        </nav>

        <main className="main">
          {isWrongNetwork ? (
            <div className="wrong-network">
              <h2>Wrong Network</h2>
              <p>Please switch to {CHAIN_NAME} to use MiniAMM</p>
            </div>
          ) : (
            <Routes>
              <Route path="/" element={
                <SwapCard provider={provider} signer={signer} account={account} />
              } />
              <Route path="/liquidity" element={
                <LiquidityCard provider={provider} signer={signer} account={account} />
              } />
            </Routes>
          )}
        </main>

        <footer className="footer">
          <p>
            MiniAMM — Uniswap V2 Style DEX | Built by Zakir Khan |{" "}
            <a href="https://github.com/zakirkhan-code/MiniAMM" target="_blank" rel="noreferrer">
              GitHub
            </a>
          </p>
        </footer>
      </div>
    </BrowserRouter>
  );
}

export default App;