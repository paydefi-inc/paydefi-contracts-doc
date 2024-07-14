# Paydefi Onchain Payment Protocol

The PayDeFi Onchain Payment Protocol leverages blockchain technology to facilitate secure transactions between payers and merchants. This protocol uses the blockchain as a settlement layer and a source of truth, offering significant advantages over traditional cryptocurrency payment methods.

What we propose:

- **Guaranteed Settlement**: Ensuring merchants receive the precise amount they request, providing consistent and reliable payments.
- **Automatic Conversion**: Allowing payers to use any token with liquidity on decentralized exchanges like Paraswap, shielding merchants from price volatility.
- **Error-Free Payments**: Eliminating the risk of incorrect payment amounts or addresses, thus enhancing transaction accuracy and reducing errors.
- **Increased Privacy**: Enabling transactions that do not require sharing sensitive financial information, thus enhancing privacy for both payers and merchants.
- **Lower Fees**: Reducing transaction fees compared to traditional payment processors, offering a cost-effective solution for merchants.
- **Decentralized Trust**: Utilizing decentralized networks to establish trust without relying on centralized intermediaries, ensuring greater transparency and security.
- **Global Reach**: Facilitating cross-border transactions without the need for currency conversion or dealing with international banking systems.

### Contract Deployments

Paydefi Payment Protocol deployed contract addresses:

| Chain     |  Address                                      |
|-----------|  -------------------------------------------- |
| Ethereum  |  `0xE19bC5BF58A0acbaBbFC48E65910Fa36e0a6347b` |
| Polygon   |  `0x67B4135eb73e3a971B4fb02fd41847339D0077d6` |
| Optimism  |  `0xB3E93afAEb136794d186b83777661886eE028d56` |
| Binance   |  `0xf9fc85f20cf21cF4aeBd68c2d9d1FA190a568679` |
| Arbitrum  |  `0xB06b542548Acc3cDa2dEc10084c90ddaa36730a7` |
| Avalanche |  `0xf9fc85f20cf21cF4aeBd68c2d9d1FA190a568679` |

Since the contract is non-upgradeable, these addresses will change when new
versions are deployed.

### Browsing this Repo

The core source code can be found in [Paydefi.sol](contracts/Paydefi.sol).

## Overview

### Contract payment methods

Depending on the settlement token and the input token, along with the way
in which the payer allows movement of their input token, a frontend must select
the appropriate method by which to complete the payment. These methods are:

- `completePayment`: The merchant wants a token and the payer wants to pay with the same token.
- `completePaymentWithSwap`: The merchant wants a token and the payer wants to pay with a different token. The calldata for one of the whitelisted swap providers should be passed in.

### Contract Guarantees

The contract ensures that, for a given valid `TransferIntent`:

- The merchant always receives the exact amount requested
- The merchant never receives payments past a stated deadline
- The merchant never receives more than one payment
- Payments may be made using the merchant's requested currency, or swapped from
  another token as part of the payment transaction
- Unsuccessful or partial payments will never reach the merchant, thus
  guaranteeing that payments are atomic. Either the merchant is correctly paid
  in full and the fee is correctly charged, or the transaction reverts and no
  state is changed onchain.


### Payment Transaction Results

When the payment is successful, a `Payment` event is emitted by the contract
with details about:

- The order id for which the payment was made
- The input token that was spent by the payer
- The output token that was sent to the merchant
- The amount of the input token spent by the payer
- The amount of the output token sent to the merchant
- The amount of the fee taken by the protocol
- The merchant address

In the case of errors, a specific error type is returned with details about what
went wrong.
