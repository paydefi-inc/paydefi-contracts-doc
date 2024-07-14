// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPaydefi.sol";
import "./libraries/PaymentErrors.sol";
import "./libraries/ERC20Utils.sol";

contract Paydefi is IPaydefi, Ownable {
    using ERC20Utils for IERC20;

    /// @notice mapping of swap providers
    mapping(address => bool) public whitelistedSwapProviders;

    /**
     * @notice Emitted when payment is completed
     * @param orderId order id
     * @param payInToken token address to pay
     * @param payOutToken token address to receive
     * @param payInAmount amount of payInToken
     * @param payOutAmount amount of payOutToken
     * @param protocolFeeAmount amount of protocol fee
     * @param merchant merchant address
     */
    event PaymentCompleted(
        string orderId,
        address payInToken,
        address payOutToken,
        uint256 payInAmount,
        uint256 payOutAmount,
        uint256 protocolFeeAmount,
        address merchant
    );

    /**
     * @notice Constructor
     * @param initialOwner initial owner address
     * @param swapProviders array of swap providers
     */
    constructor(address initialOwner, address[] memory swapProviders) Ownable(initialOwner) {
        for (uint256 i = 0; i < swapProviders.length; i++) {
            whitelistedSwapProviders[swapProviders[i]] = true;
        }
    }

    /**
     * @notice check if payment is expired
     * @param expiry expiry timestamp
     */
    modifier whenNotExpired(uint256 expiry) {
        if (expiry < block.timestamp) {
            revert PaymentErrors.PaymentExpired();
        }

        _;
    }

    /**
     * @notice complete payment with direct transfer
     * @param payment payment arguments
     */
    function completeTransferPayment(Payment calldata payment) external payable whenNotExpired(payment.expiry) {
        // transfer payInToken to the contract
        if (IERC20(payment.payInToken).isETH(payment.payInAmount) == 0) {
            IERC20(payment.payInToken).safeTransferFrom(msg.sender, address(this), payment.payInAmount);
        }

        uint256 feeCollected = payment.payInAmount - payment.payOutAmount;

        IERC20(payment.payInToken).safeTransfer(payment.merchant, payment.payOutAmount);

        emit PaymentCompleted(
            payment.orderId,
            payment.payInToken,
            payment.payInToken,
            payment.payInAmount,
            payment.payOutAmount,
            feeCollected,
            payment.merchant
        );
    }

    /**
     * @notice complete payment with swap
     * @param payment payment arguments
     * @param swapData swap arguments
     */
    function completeSwapPayment(
        Payment calldata payment,
        SwapData calldata swapData
    ) external payable whenNotExpired(payment.expiry) {
        if (!whitelistedSwapProviders[swapData.provider]) {
            revert PaymentErrors.SwapProviderNotWhitelisted();
        }

        (uint256 actualPayInAmount, uint256 receivedPayOutAmount) = executeSwap(payment, swapData);

        uint256 feeCollected = receivedPayOutAmount - payment.payOutAmount;

        // transfer payOutToken to merchant
        IERC20(payment.payOutToken).safeTransfer(payment.merchant, payment.payOutAmount);

        // if swap is a BUY, return unused payInAmount to user
        if (swapData.swapType == SwapType.BUY) {
            uint256 unusedPayInAmount = payment.payInAmount - actualPayInAmount;

            if (unusedPayInAmount > 0) {
                IERC20(payment.payInToken).safeTransfer(msg.sender, unusedPayInAmount);
            }
        }

        emit PaymentCompleted(
            payment.orderId,
            payment.payInToken,
            payment.payOutToken,
            actualPayInAmount,
            payment.payOutAmount,
            feeCollected,
            payment.merchant
        );
    }

    /**
     * @notice add address of the swap provider
     * @param swapProvider swap provider address
     */
    function addWhitelistedSwapProvider(address swapProvider) external onlyOwner {
        whitelistedSwapProviders[swapProvider] = true;
    }

    /**
     * @notice Remove address of the swap provider
     * @param swapProvider swap provider address
     */
    function removeWhitelistedSwapProvider(address swapProvider) external onlyOwner {
        whitelistedSwapProviders[swapProvider] = false;
    }

    /**
     * @notice Returns amount of protocol fees collected for the token
     */
    function protocolFee(address token) public view returns (uint256) {
        return IERC20(token).getBalance(address(this));
    }

    /**
     * @notice claim protocol fee
     * @param token token address
     * @param receiver receiver address
     */
    function claimProtocolFee(address token, address receiver) external onlyOwner {
        if (receiver == address(0)) {
            revert PaymentErrors.ZeroClaimAddress();
        }

        uint256 protocolFeeAmount = protocolFee(token);
        IERC20(token).safeTransfer(receiver, protocolFeeAmount);
    }

    /**
     * @notice remove approval for spender
     * @param token token address
     * @param spender spender address
     */
    function removeApproval(address token, address spender) external onlyOwner {
        IERC20(token).approve(spender, 0);
    }

    /**
     * @notice execute swap
     * @param payment payment arguments
     * @param swapData swap arguments
     * @return spent amount of payInToken
     * @return received amount of payOutToken
     */
    function executeSwap(
        Payment calldata payment,
        SwapData calldata swapData
    ) internal returns (uint256 spent, uint256 received) {
        if (IERC20(payment.payInToken).isETH(payment.payInAmount) == 0) {
            IERC20(payment.payInToken).safeTransferFrom(msg.sender, address(this), payment.payInAmount);
            if (swapData.shouldApprove) {
                IERC20(payment.payInToken).approve(swapData.provider);
            }
        }

        uint256 payInBeforeSwap = IERC20(payment.payInToken).getBalance(address(this));
        uint256 payOutBeforeSwap = IERC20(payment.payOutToken).getBalance(address(this));

        (bool success, ) = swapData.provider.call{value: swapData.value}(swapData.callData);

        /** @dev assembly allows to get tx failure reason here*/
        if (success == false) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }

        uint256 payInAfterSwap = IERC20(payment.payInToken).getBalance(address(this));
        uint256 payOutAfterSwap = IERC20(payment.payOutToken).getBalance(address(this));

        spent = payInBeforeSwap - payInAfterSwap;
        received = payOutAfterSwap - payOutBeforeSwap;
    }
}
