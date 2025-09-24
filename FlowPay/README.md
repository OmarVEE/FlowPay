# FlowPay - Dynamic Payment Flow Management System

FlowPay is an advanced smart contract built on the Stacks blockchain that enables dynamic payment flow management through automated payment channels. It facilitates progressive value distribution over time, allowing users to establish continuous payment flows with precise control and automated execution.

## Features

- **Dynamic Payment Channels**: Create automated payment flows that distribute value progressively over time
- **Block-Based Distribution**: Payments flow on a per-block basis with customizable rates
- **Flexible Channel Management**: Full control over payment channel lifecycle and parameters
- **Secure Fund Escrow**: Built-in fund locking with guaranteed payment execution
- **Low Platform Fees**: Configurable platform fees (default 3%)
- **Multi-Party Control**: Both payers and payees can manage channel lifecycle

## Core Concepts

### Flow Channels
A flow channel represents a continuous payment stream from a payer to a payee over a specified duration. Each channel includes:
- **Rate per Block**: Amount of micro-STX distributed per block
- **Channel Lifespan**: Total number of blocks the channel remains active
- **Deposited Amount**: Total funds locked for the entire channel duration

### User Wallets
Internal wallet system within the contract that provides:
- Efficient fund management and allocation
- Reduced gas costs for multiple operations
- Seamless integration with payment channels

## Usage Guide

### For Payers

1. **Fund Your Wallet**
   ```clarity
   (add-funds amount)
   ```
   Deposit STX tokens into your internal wallet to fund payment channels.

2. **Establish a Flow Channel**
   ```clarity
   (establish-flow-channel payee rate-per-block channel-lifespan)
   ```
   - `payee`: Principal address of the payment recipient
   - `rate-per-block`: Micro-STX amount distributed per block
   - `channel-lifespan`: Total blocks for the channel duration

3. **Close a Channel**
   ```clarity
   (close-flow-channel channel-id)
   ```
   Terminate an active channel and recover unused funds.

### For Payees

1. **Collect Payments**
   ```clarity
   (collect-payment channel-id)
   ```
   Withdraw available payments from an active flow channel.

### General Functions

1. **Withdraw Funds**
   ```clarity
   (remove-funds amount)
   ```
   Withdraw STX tokens from your internal wallet balance.

2. **Check Channel Information**
   ```clarity
   (get-channel-info channel-id)
   ```
   Retrieve complete details about a specific payment channel.

3. **Calculate Claimable Amount**
   ```clarity
   (compute-claimable-amount channel-id)
   ```
   Determine how much can be claimed from a channel at the current block.

## Technical Specifications

### Configuration Parameters
- **Platform Fee**: 3% (300 basis points) - adjustable by system admin
- **Minimum Channel Size**: 1000 micro-STX
- **Maximum Platform Fee**: 20% (2000 basis points)

### Error Codes
- `u600`: Admin-only function accessed by non-admin
- `u601`: Channel not found or doesn't exist
- `u602`: Insufficient funds in wallet
- `u603`: Invalid input parameters provided
- `u604`: Channel is already closed/inactive
- `u605`: Access denied - unauthorized operation

### Data Structures

#### Flow Channels
```clarity
{
    payer: principal,
    payee: principal,
    rate-per-block: uint,
    deposited-amount: uint,
    creation-block: uint,
    expiration-block: uint,
    claimed-amount: uint,
    channel-active: bool
}
```

#### User Wallets
```clarity
{
    user-address: principal,
    wallet-balance: uint
}
```

## Security Features

- **Access Control**: Strict permissions for channel operations
- **Fund Protection**: Secure escrow with automatic fund distribution
- **Parameter Validation**: Comprehensive input validation and bounds checking
- **Safe Closure**: Proper settlement of all outstanding payments on channel closure
- **Admin Safeguards**: Limited administrative powers with safety constraints

## Use Cases

- **Recurring Payments**: Automated subscription and membership fees
- **Payroll Systems**: Employee salary distribution over time
- **Service Agreements**: Progressive payments for ongoing services
- **Rental Agreements**: Automated rent and lease payments
- **Project Funding**: Milestone-based payment releases
- **Investment Distributions**: Regular dividend or profit sharing

## Advanced Features

### Progressive Distribution
Payments are calculated and distributed based on elapsed blocks, ensuring fair and predictable value transfer over time.

### Channel Lifecycle Management
Complete control over payment channels from creation to closure, with automatic settlement of all outstanding amounts.

### Dual-Party Control
Both payers and payees can initiate channel closure, providing flexibility and protection for all parties.

## System Administration

The system admin (contract deployer) can:
- Adjust platform fee rates (capped at 20%)
- Modify minimum channel size requirements
- Monitor system-wide channel activity

Note: Admins cannot access user funds or interfere with active channels.

## Getting Started

1. Deploy the FlowPay contract to the Stacks blockchain
2. Fund your internal wallet using `add-funds`
3. Establish your first payment channel
4. Recipients can collect payments as they become available over time
