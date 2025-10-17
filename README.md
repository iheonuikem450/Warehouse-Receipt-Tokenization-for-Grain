# 🌾 Warehouse Receipt Tokenization for Grain

Transform grain storage into liquid, tradable assets through blockchain-powered warehouse receipts that enable instant collateralized lending and seamless trading.

## 🚀 Overview

This smart contract creates a revolutionary system for tokenizing grain warehouse receipts, allowing farmers and traders to:
- 📄 Convert physical grain storage into NFT receipts
- 💰 Use receipts as collateral for instant loans
- 🔄 Trade receipts on secondary markets
- ⚡ Access immediate liquidity without moving grain

## 🛠️ Features

### 🏪 Warehouse Management
- Authorize trusted warehouses to issue receipts
- Track grain type, quantity, and quality grades
- Set expiration dates for storage periods

### 🎫 Receipt System
- Mint NFT receipts representing stored grain
- Transfer receipts between parties
- Redeem receipts for fungible grain tokens

### 💳 Collateralized Lending
- Create loans using receipts as collateral
- Automated collateral ratio enforcement (150% minimum)
- Interest rate calculations and repayment tracking

### 💹 Price Oracle
- Dynamic grain pricing system
- Support for multiple grain types
- Market-based collateral valuations

## 📋 Usage Instructions

### For Contract Owners
```clarity
;; Authorize a warehouse
(contract-call? .warehouse-receipt-tokenization authorize-warehouse 'SP1WAREHOUSE...)

;; Set grain prices (price in micro-units)
(contract-call? .warehouse-receipt-tokenization set-grain-price "wheat" u250000)
```

### For Warehouses
```clarity
;; Issue a warehouse receipt
(contract-call? .warehouse-receipt-tokenization issue-receipt 
  "wheat"        ;; grain type
  u1000         ;; quantity in tons
  "Grade-A"     ;; quality grade
  u52560        ;; expires in ~1 year (blocks)
)
```

### For Receipt Holders
```clarity
;; Transfer receipt to another party
(contract-call? .warehouse-receipt-tokenization transfer-receipt u1 'SP2RECIPIENT...)

;; Redeem receipt for grain tokens
(contract-call? .warehouse-receipt-tokenization redeem-receipt u1)

;; Create collateralized loan
(contract-call? .warehouse-receipt-tokenization create-loan
  u1            ;; receipt ID as collateral
  u150000       ;; loan amount
  u500          ;; 5% interest rate (basis points)
  u4320         ;; 30-day loan term
)

;; Repay loan to get collateral back
(contract-call? .warehouse-receipt-tokenization repay-loan u1)
```

## 🔧 Contract Functions

### 📖 Read-Only Functions
- `get-receipt-info(uint)` - Get receipt details
- `get-grain-price(string-ascii)` - Check current grain prices
- `get-loan-info(uint)` - View loan details
- `is-warehouse-authorized(principal)` - Check warehouse status

### ✍️ Public Functions
- `issue-receipt()` - Mint new warehouse receipt
- `transfer-receipt()` - Transfer receipt ownership
- `redeem-receipt()` - Convert receipt to grain tokens
- `create-loan()` - Borrow against receipt collateral
- `repay-loan()` - Repay loan and reclaim collateral

## 🏗️ Smart Contract Architecture

The contract implements:
- **SIP-010 Fungible Token** (GRAIN) for liquid grain representation
- **Non-Fungible Tokens** for unique warehouse receipts
- **Collateral Management** with automated liquidation protection
- **Access Controls** for warehouse authorization
- **Time-based Expiration** for storage validity

## 🛡️ Security Features

- ✅ Owner-only warehouse authorization
- ✅ Collateral ratio enforcement (150% minimum)
- ✅ Time-based receipt expiration
- ✅ Double-spending prevention
- ✅ Access control validation

## 🚦 Getting Started

1. **Deploy Contract**: Use Clarinet to deploy on Stacks testnet/mainnet
2. **Authorize Warehouses**: Add trusted storage facilities
3. **Set Grain Prices**: Configure market rates for different grains
4. **Issue Receipts**: Warehouses can start tokenizing stored grain
5. **Enable Trading**: Receipts become tradable assets

## 📊 Token Economics

- **GRAIN Token**: Represents redeemable grain units
- **Warehouse Receipts**: Unique NFTs for specific grain lots
- **Collateral Loans**: 150% collateralization required
- **Interest Rates**: Configurable per loan in basis points

## 🧪 Testing

Run tests using Clarinet:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request

## 📜 License

MIT License - Build the future of agricultural finance! 🌱

---

*Empowering farmers and traders with instant liquidity through tokenized grain receipts* 🚜✨
