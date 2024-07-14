// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

library PaymentErrors {
    error IncorrectNativeTokenAmount();
    error SwapProviderNotWhitelisted();
    error FeeRateOutOfRange();
    error ZeroClaimAddress();
    error PaymentExpired();
}
