// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IPaydefi {
    enum SwapType {
        SEll,
        BUY
    }

    struct Payment {
        string orderId;
        address payInToken;
        address payOutToken;
        uint256 payInAmount;
        uint256 payOutAmount;
        address merchant;
        uint256 expiry;
    }

    struct SwapData {
        SwapType swapType;
        address provider;
        uint256 value;
        bytes callData;
        bool shouldApprove;
    }

    function completeTransferPayment(Payment calldata payment) external payable;

    function completeSwapPayment(Payment calldata payment, SwapData calldata swapData) external payable;

    function claimProtocolFee(address token, address receiver) external;

    function addWhitelistedSwapProvider(address swapProvider) external;

    function removeWhitelistedSwapProvider(address swapProvider) external;
}
