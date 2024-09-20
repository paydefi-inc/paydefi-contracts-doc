// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IPaydefi {
    enum SwapType {
        SEll,
        BUY
    }

    struct TransferData {
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

    function completeTransferPayment(TransferData calldata payment) external payable;

    function completeTransferDonation(TransferData calldata donation) external payable;

    function completeSwapPayment(TransferData calldata payment, SwapData calldata swapData) external payable;

    function completeSwapDonation(TransferData calldata donation, SwapData calldata swapData) external payable;

    function claimProtocolFee(address token, address receiver) external;

    function addWhitelistedSwapProvider(address swapProvider) external;

    function removeWhitelistedSwapProvider(address swapProvider) external;
}
