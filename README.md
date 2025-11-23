# Uniswap V3 LP Locker

A smart contract system for permanently locking Uniswap V3 liquidity position NFTs while still allowing fee collection. This enables users to commit their liquidity positions indefinitely while maintaining the ability to collect trading fees.

## Overview

The system consists of two main contracts:

- **UniV3PermanentLocker**: A contract that locks a single Uniswap V3 LP NFT forever. Once locked, the position cannot be withdrawn, but fees can still be collected.
- **UniV3PermanentLockerFactory**: A factory contract that deploys locker instances at deterministic addresses using CREATE3.

## Features

- 🔒 **Permanent Lock**: Once a position is locked, it cannot be withdrawn
- 💰 **Fee Collection**: Collect trading fees from locked positions
- 🏭 **Deterministic Deployment**: Factory deploys lockers at predictable addresses
- ✍️ **Permit Support**: Deploy lockers using ERC721 permit signatures (no approval transaction needed)
- 🔓 **Ownerless Mode**: After renouncing ownership, anyone can collect fees
- 🎯 **Configurable Fee Recipient**: Owner can set a dedicated address that receives fees

## Architecture

### UniV3PermanentLocker

The locker contract:

- Accepts a single Uniswap V3 LP NFT during construction
- Verifies ownership of the NFT before locking
- Allows the owner to collect fees from the locked position
- Supports ownerless mode: if ownership is renounced, anyone can collect fees
- Sends fees to a configurable `feeRecipient` that the owner can update

**Key Functions:**

- `collect(amount0Max, amount1Max)`: Collect fees to the configured fee recipient
- `collectAll()`: Collect all available fees to the configured fee recipient
- `setFeeRecipient(newRecipient)`: Update the address that receives collected fees

### UniV3PermanentLockerFactory

The factory contract:

- Deploys locker instances using CREATE3 for deterministic addresses
- Transfers the NFT to the predicted locker address before deployment
- Supports both standard approval and permit-based deployment

**Key Functions:**

- `deploy(owner, tokenId)`: Deploy a locker with standard approval
- `deployWithPermit(owner, tokenId, deadline, v, r, s)`: Deploy using ERC721 permit
- `predict(tokenId)`: Predict the locker address for a given token ID

## Installation

This project uses [Foundry](https://book.getfoundry.sh/). Install Foundry if you haven't already:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Then install dependencies:

```bash
forge install
```

## Deployment

### Deploying the Factory

The factory contract can be deployed using the provided deployment script.

1. Create a `.env` file with the following variables:

```bash
RPC_URL=<your_rpc_url>
PRIVATE_KEY=<your_private_key>
```

2. Run the deployment script:

```bash
chmod +x script/deploy.sh
./script/deploy.sh <positionManagerAddress>
```

The script uses CreateX (CREATE2) for deterministic deployment. The factory will be deployed at a predictable address based on the deployer's address and salt.

Alternatively, you can deploy manually using Foundry:

```bash
forge script script/Deploy.s.sol:DeployScript --sig "deploy(address)" <positionManagerAddress> --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## Usage

### Deploying a Locker

#### Standard Deployment

1. Approve the factory to transfer your NFT:

```solidity
positionManager.approve(factoryAddress, tokenId);
```

2. Deploy the locker:

```solidity
address lockerAddress = factory.deploy(ownerAddress, tokenId);
```

#### Permit-Based Deployment

Deploy without a prior approval transaction using ERC721 permit:

```solidity
address lockerAddress = factory.deployWithPermit(
    ownerAddress,
    tokenId,
    deadline,
    v,
    r,
    s
);
```

### Collecting Fees

Set the desired fee recipient (defaults to the owner) and call the collect functions. After the owner renounces
ownership, the fee recipient remains whichever address was last configured.

#### As Owner

```solidity
// Collect specific amounts
locker.collect(amount0Max, amount1Max);

// Collect all available fees
locker.collectAll();
```

#### After Renouncing Ownership

Once ownership is renounced, anyone can call `collect` / `collectAll`. Be sure to set the desired fee recipient before
renouncing ownership:

```solidity
// Set the fee recipient (only callable by the owner)
locker.setFeeRecipient(recipientAddress);

// After renouncing ownership, anyone can collect fees
locker.collect(amount0Max, amount1Max);
locker.collectAll();
```

## Testing

Run the test suite:

```bash
forge test
```

Run with verbosity:

```bash
forge test -vvv
```

## Project Structure

```
.
├── src/
│   ├── UniV3PermanentLocker.sol          # Main locker contract
│   ├── UniV3PermanentLockerFactory.sol   # Factory contract
│   └── interfaces/
│       ├── INonfungiblePositionManager.sol
│       └── IERC721Permit.sol
├── test/
│   ├── UniV3PermanentLocker.t.sol        # Locker tests
│   ├── UniV3PermanentLockerFactory.t.sol # Factory tests
│   └── mocks/
│       └── MockPositionManager.sol        # Mock for testing
└── script/
    ├── Deploy.s.sol                       # Deployment script
    └── deploy.sh                          # Deployment shell script
```

## Security Considerations

- **Permanent Lock**: Once locked, positions cannot be withdrawn. Ensure this is the intended behavior.
- **Ownerless Mode**: After renouncing ownership, anyone can collect fees to the last configured fee recipient. Set it before renouncing ownership.
- **Token Ownership**: The factory must receive the NFT before deployment. The locker verifies ownership during construction.

## License

MIT
