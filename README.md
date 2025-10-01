# 🏗️ Proof-of-Work Contribution Tracker

A Clarity smart contract that tracks and rewards verifiable contributions using commit hashes from GitHub and other development platforms.

## 📋 Overview

This smart contract enables developers to submit proof of their contributions (Git commit hashes) and receive STX rewards for verified work. It creates a transparent, blockchain-based system for tracking and incentivizing open-source contributions.

## 🚀 Features

- **👥 Contributor Registration**: Developers can register as contributors
- **📝 Contribution Submission**: Submit Git commit hashes with repository information
- **✅ Verification System**: Contract owner can verify legitimate contributions
- **💰 Reward Distribution**: Automatic STX rewards for verified contributions
- **📊 Statistics Tracking**: Comprehensive stats for contributors and the contract
- **🔍 Hash Verification**: Prevents duplicate submissions using commit hash tracking

## 🔧 Contract Functions

### Public Functions

#### `register-contributor()`
Register as a new contributor to the platform.

#### `submit-contribution(commit-hash, repository)`
Submit a contribution with:
- `commit-hash`: 32-byte buffer containing the Git commit hash
- `repository`: ASCII string (max 100 chars) identifying the repository

#### `verify-contribution(contribution-id)`
**Owner only**: Verify a submitted contribution by its ID.

#### `claim-reward(contribution-id)`
Claim STX rewards for a verified contribution.

#### `update-reward-amount(new-reward)`
**Owner only**: Update the reward amount per contribution.

#### `fund-contract()`
Add STX to the contract balance for reward distribution.

### Read-Only Functions

#### `get-contributor(contributor)`
Get contributor information including stats and verification status.

#### `get-contribution(contribution-id)`
Get details about a specific contribution.

#### `get-contribution-by-hash(commit-hash)`
Find a contribution using its commit hash.

#### `get-contract-stats()`
Get overall contract statistics:
- Total contributors
- Total contributions
- Reward per contribution
- Contract balance

#### `get-contributor-stats(contributor)`
Get detailed statistics for a specific contributor.

#### `is-hash-used(commit-hash)`
Check if a commit hash has already been submitted.

#### `get-reward-amount()`
Get the current reward amount per contribution.

## 🛠️ Usage Instructions

### 1. **Deploy the Contract**
```bash
clarinet deploy
```

### 2. **Register as a Contributor**
```clarity
(contract-call? .proof-of-work-contribution-tracker register-contributor)
```

### 3. **Submit a Contribution**
```clarity
(contract-call? .proof-of-work-contribution-tracker submit-contribution 
  0x1234567890abcdef1234567890abcdef12345678 
  "my-awesome-repo")
```

### 4. **Fund the Contract (Owner)**
```clarity
(contract-call? .proof-of-work-contribution-tracker fund-contract)
```

### 5. **Verify Contributions (Owner)**
```clarity
(contract-call? .proof-of-work-contribution-tracker verify-contribution u0)
```

### 6. **Claim Rewards**
```clarity
(contract-call? .proof-of-work-contribution-tracker claim-reward u0)
```

## 📊 Data Structure

### Contributors Map
- `contributions`: Number of contributions submitted
- `total-rewards`: Total STX rewards earned
- `first-contribution-block`: Block height of first contribution
- `last-contribution-block`: Block height of most recent contribution
- `verified`: Whether contributor has been verified

### Contributions Map
- `contributor`: Principal address of contributor
- `commit-hash`: 32-byte Git commit hash
- `repository`: Repository name/identifier
- `timestamp`: Block timestamp
- `block-height`: Stacks block height
- `verified`: Whether contribution is verified
- `reward-claimed`: Whether reward has been claimed

## 🔒 Security Features

- **Owner-only verification**: Only contract owner can verify contributions
- **Duplicate prevention**: Commit hashes can only be submitted once
- **Balance checks**: Ensures sufficient contract balance before rewards
- **Contributor validation**: Contributors must be registered

## 🎯 Error Codes

- `u100`: Unauthorized access
- `u101`: Already exists
- `u102`: Not found
- `u103`: Invalid hash
- `u104`: Insufficient balance
- `u105`: Invalid reward amount

## 💡 Example Workflow

1. **👤 Developer registers** as a contributor
2. **📤 Submits contribution** with commit hash and repo info
3. **🔍 Owner reviews** and verifies the contribution
4. **💰 Developer claims** STX reward for verified work
5. **📈 Stats update** automatically across the platform

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📜 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for improvements.

---

*Built with ❤️ using Clarity and Clarinet*
