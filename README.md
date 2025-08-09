# CustomBasket

**Synthetic Assets – Create synthetic exposure to traditional assets through user-defined multi-asset synthetic portfolios**

CustomBasket is a smart contract built on the Stacks blockchain that enables users to create and manage synthetic asset baskets. These baskets provide exposure to traditional assets through tokenized portfolios, allowing for diversified investment strategies and programmable asset allocation.

## Features

- **Multi-Asset Synthetic Portfolios**: Create custom baskets with up to 10 different assets
- **Flexible Asset Weights**: Define precise allocation percentages for each asset in your basket
- **Synthetic Token Issuance**: Mint and burn fungible tokens representing basket shares
- **Price Feed Integration**: Support for oracle price feeds for accurate asset valuation
- **Protocol Fee Structure**: Built-in fee mechanism for sustainable protocol operation
- **Transfer & Trading**: Transfer basket tokens between users
- **TVL Tracking**: Monitor Total Value Locked across all baskets
- **Access Control**: Secure ownership and authorization mechanisms
- **Basket Management**: Create, deactivate, and manage basket lifecycles

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Token Standard**: Fungible Token (SIP-010)
- **Clarity Version**: 2
- **Epoch**: 2.5
- **Maximum Assets per Basket**: 10
- **Precision**: 1,000,000 (6 decimal places)
- **Default Protocol Fee**: 0.01% (100/1,000,000)

## Architecture

### Core Components

1. **Synthetic Basket Token**: Fungible token representing shares in synthetic asset baskets
2. **Basket Registry**: Storage for basket metadata and configuration
3. **Asset Management**: Approved asset registry with price feed integration
4. **Balance Tracking**: User balance management per basket
5. **TVL Monitoring**: Total Value Locked calculation and tracking

### Data Structures

- **baskets**: Basket metadata including creator, name, description, supply, and status
- **basket-assets**: Asset composition with weights and price feeds
- **user-balances**: User token balances per basket
- **approved-assets**: Whitelist of approved assets for basket creation
- **basket-tvl**: Total Value Locked per basket

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing
- Stacks wallet for deployment

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd CustomBasket
```

2. Navigate to the contract directory:
```bash
cd CustomBasket_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

5. Run tests:
```bash
npm test
```

## Usage Examples

### 1. Adding Approved Assets (Owner Only)

```clarity
;; Add BTC with price feed
(contract-call? .CustomBasket add-approved-asset "BTC" (some 'SP1234...PRICE-FEED))

;; Add ETH without price feed
(contract-call? .CustomBasket add-approved-asset "ETH" none)
```

### 2. Creating a Synthetic Basket

```clarity
;; Create a balanced crypto basket
(contract-call? .CustomBasket create-basket
  "Crypto Basket"
  "50% BTC, 30% ETH, 20% SOL exposure"
  (list 
    { symbol: "BTC", weight: u500000 }    ;; 50%
    { symbol: "ETH", weight: u300000 }    ;; 30%
    { symbol: "SOL", weight: u200000 }    ;; 20%
  )
)
```

### 3. Minting Basket Tokens

```clarity
;; Mint 1000 tokens for basket ID 1
(contract-call? .CustomBasket mint-basket-tokens u1 u1000000)
```

### 4. Transferring Basket Tokens

```clarity
;; Transfer 500 tokens to another user
(contract-call? .CustomBasket transfer-basket-tokens 
  u1 
  u500000 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 5. Burning Tokens for Redemption

```clarity
;; Burn 250 tokens from basket ID 1
(contract-call? .CustomBasket burn-basket-tokens u1 u250000)
```

## Contract Functions Documentation

### Public Functions

#### Administrative Functions

- **`add-approved-asset`**: Add asset to approved list (owner only)
- **`set-protocol-fee`**: Update protocol fee (owner only)

#### Basket Management

- **`create-basket`**: Create new synthetic asset basket
- **`deactivate-basket`**: Deactivate basket (creator only)

#### Token Operations

- **`mint-basket-tokens`**: Mint basket tokens
- **`burn-basket-tokens`**: Burn basket tokens for redemption
- **`transfer-basket-tokens`**: Transfer tokens between users

### Read-Only Functions

- **`get-basket-info`**: Get basket metadata
- **`get-user-basket-balance`**: Get user balance for specific basket
- **`get-basket-asset`**: Get asset composition details
- **`get-total-baskets`**: Get total number of baskets created
- **`get-protocol-fee`**: Get current protocol fee
- **`is-approved-asset`**: Check if asset is approved
- **`get-basket-tvl`**: Get Total Value Locked for basket
- **`get-balance`**: Get user's synthetic token balance
- **`get-total-supply`**: Get total supply of synthetic tokens

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-OWNER-ONLY | Only contract owner can perform this action |
| 101 | ERR-NOT-TOKEN-OWNER | Not authorized as token owner |
| 102 | ERR-INVALID-AMOUNT | Invalid amount specified |
| 103 | ERR-BASKET-NOT-FOUND | Basket does not exist |
| 104 | ERR-INSUFFICIENT-BALANCE | Insufficient token balance |
| 105 | ERR-INVALID-ASSET | Asset not approved or invalid |
| 106 | ERR-BASKET-EXISTS | Basket already exists |
| 107 | ERR-INVALID-WEIGHT | Invalid weight allocation |
| 108 | ERR-MAX-ASSETS-EXCEEDED | Too many assets in basket |
| 109 | ERR-UNAUTHORIZED | Unauthorized access |

## Deployment Guide

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet integrate deploy --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Ensure sufficient STX for deployment fees
3. Deploy to mainnet:
```bash
clarinet integrate deploy --mainnet
```

### Post-Deployment Setup

1. Add approved assets using `add-approved-asset`
2. Configure price feeds if using oracles
3. Set appropriate protocol fees
4. Test basket creation and token operations

## Security Notes

### Access Control
- Contract owner has exclusive rights to add approved assets and set fees
- Basket creators can deactivate their own baskets
- Users can only manage their own token balances

### Input Validation
- All asset weights must sum to exactly 100% (1,000,000 precision units)
- Maximum 10 assets per basket to prevent gas limit issues
- Amount validation prevents zero or negative transactions
- Asset approval checking prevents unauthorized asset inclusion

### Economic Security
- Protocol fee mechanism provides sustainable revenue model
- TVL tracking enables monitoring of contract usage
- Token burning mechanics ensure proper redemption

### Best Practices
- Always verify asset approvals before basket creation
- Monitor gas usage for complex basket operations
- Implement proper error handling in client applications
- Use price feeds for accurate asset valuation

## Development

### Testing
Run the test suite:
```bash
npm test
```

### Code Quality
Check contract syntax and analysis:
```bash
clarinet check
```

### Integration Testing
Test against local devnet:
```bash
clarinet integrate
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with appropriate tests
4. Ensure all tests pass
5. Submit a pull request

## License

[Specify your license here]

## Disclaimer

This smart contract handles financial instruments. Users should:
- Understand the risks involved in synthetic asset exposure
- Verify all transactions before execution
- Consider the implications of protocol fees
- Ensure proper testing before mainnet usage

**This software is provided "as is" without warranty of any kind.**
