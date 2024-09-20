# Paydefi Onchain Transfer Protocol

The PayDeFi Onchain Transfer Protocol leverages blockchain technology to facilitate secure transactions between payers and merchants. This protocol uses the blockchain as a settlement layer and a source of truth, offering significant advantages over traditional cryptocurrency transfer methods.

What we propose:

- **Guaranteed Settlement**: Ensuring merchants receive the exact amount requested, providing reliable payments and donations.
- **Automatic Conversion**: Allowing payers to use any token with liquidity on decentralized exchanges like Paraswap, shielding merchants from price volatility.
- **Error-Free Transfers**: Eliminating the risk of incorrect transfer amounts, addresses, or deadlines, thus enhancing transaction accuracy and reducing errors.
- **Increased Privacy**: Enabling transactions that do not require sharing sensitive financial information, thus enhancing privacy for both payers and merchants.
- **Lower Fees**: Reducing transaction fees compared to traditional payment processors, offering a cost-effective solution for merchants.
- **Decentralized Trust**: Utilizing decentralized networks to establish trust without relying on centralized intermediaries, ensuring greater transparency and security.
- **Global Reach**: Facilitating cross-border transactions without the need for currency conversion or dealing with international banking systems.

### Contract Deployments

The Paydefi Onchain Transfer Protocol utilizes a UUPS proxy pattern. The contract deployment consists of a proxy address that remains constant and an implementation address that can be updated to a new version.

**Proxy Address**:

| Chain     | Address                                      |
| --------- | -------------------------------------------- |
| Ethereum  | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |
| Polygon   | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |
| Optimism  | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |
| Binance   | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |
| Arbitrum  | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |
| Avalanche | `0x0a9AF250bA479471B5ccE8987567122F8d6C73bc` |

**Current Implementation Addresses**:

| Chain     | Address                                      |
| --------- | -------------------------------------------- |
| Ethereum  | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |
| Polygon   | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |
| Optimism  | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |
| Binance   | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |
| Arbitrum  | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |
| Avalanche | `0x4834F58aE86E0d0f067aD8633d4C6D5fec330A24` |

### Browsing this Repo

The core source code can be found in [Paydefi.sol](contracts/Paydefi.sol).

## Overview

### Contract Payment and Donation Methods

Depending on the settlement token and the input token, along with the way
in which the payer allows movement of their input token, a frontend must select
the appropriate method to complete either a payment or a donation. These methods are:

#### Payments

- `completeTransferPayment`: The merchant wants a token and the payer wants to pay with the same token.
- `completeSwapPayment`: The merchant wants a token and the payer wants to pay with a different token. The calldata for one of the whitelisted swap providers should be passed in.

#### Donations

- `completeTransferDonation`: The merchant wants a token and the payer wants to pay with the same token.
- `completeSwapDonation`: The merchant wants a token and the payer wants to pay with a different token. The calldata for one of the whitelisted swap providers should be passed in.

### Contract Guarantees

#### Payments

The contract ensures that, for a given valid `Payment`:

- The merchant always receives the exact amount requested.
- The merchant never receives payments past a stated deadline.
- The merchant never receives more than one payment for a specific order.
- The merchant can receive payments using the requested currency or swapped from another token as part of the payment transaction.

#### Donations

The contract ensures that, for a given valid `Donation`:

- The merchant receives donation amounts defined by the payer.
- The merchant can receive multiple donations for a specific donation box.
- The merchant can receive donations indefinitely, as there is no deadline.
- The merchant can receive donations using the requested currency or swapped from another token as part of the donation transaction.

### Transaction Results

When a transaction is successful, the contract emits the corresponding event with details:

#### Payment Transactions:

- **Event**: `PaymentCompleted`

  - The order id for which the payment was made.
  - The input token that was spent by the payer.
  - The output token that was sent to the merchant.
  - The amount of the input token spent by the payer.
  - The amount of the output token sent to the merchant.
  - The amount of the fee taken by the protocol.
  - The merchant's address.

#### Donation Transactions:

- **Event**: `DonationCompleted`
  - The donation id for which the donation was made.
  - The input token that was spent by the payer.
  - The output token that was sent to the merchant.
  - The amount of the input token spent by the payer.
  - The amount of the output token sent to the merchant.
  - The amount of the fee taken by the protocol.
  - The merchant's address.

In the case of errors, a specific error type is returned with details about what
went wrong.
