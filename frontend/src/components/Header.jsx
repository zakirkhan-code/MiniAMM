import { CHAIN_NAME, EXPLORER_URL } from "../config";

function Header({ account, chainId, isWrongNetwork, onConnect }) {
  const shortAddress = account
    ? account.slice(0, 6) + "..." + account.slice(-4)
    : "";

  return (
    <header className="header">
      <div className="header-left">
        <h1 className="logo">MiniAMM</h1>
        <span className="logo-sub">Uniswap V2 DEX</span>
      </div>

      <div className="header-right">
        {account ? (
          <div className="wallet-info">
            <span className={`network-badge ${isWrongNetwork ? "wrong" : "correct"}`}>
              {isWrongNetwork ? "Wrong Network" : CHAIN_NAME}
            </span>
            
              <a href={`${EXPLORER_URL}/address/${account}`}
              target="_blank"
              rel="noreferrer"
              className="address-badge"
            >
              {shortAddress}
            </a>
          </div>
        ) : (
          <button className="connect-btn" onClick={onConnect}>
            Connect Wallet
          </button>
        )}
      </div>
    </header>
  );
}

export default Header;