// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IPaydefi.sol";
import "./libraries/PaymentErrors.sol";
import "./libraries/ERC20Utils.sol";

contract Paydefi is IPaydefi, Initializable, UUPSUpgradeable, OwnableUpgradeable {
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
     * @notice Emitted when a donation is completed
     * @param donationId donation id
     * @param payInToken token address to pay
     * @param payOutToken token address to receive
     * @param payInAmount amount of payInToken
     * @param payOutAmount amount of payOutToken
     * @param protocolFeeAmount amount of protocol fee
     * @param merchant merchant address
     */
    event DonationCompleted(
        string donationId,
        address payInToken,
        address payOutToken,
        uint256 payInAmount,
        uint256 payOutAmount,
        uint256 protocolFeeAmount,
        address merchant
    );

    /**
     * @notice Initializes the contract
     * @param initialOwner initial owner address
     * @param swapProviders array of swap providers
     */
    function initialize(address initialOwner, address[] memory swapProviders) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();  

        for (uint256 i = 0; i < swapProviders.length; i++) {
            whitelistedSwapProviders[swapProviders[i]] = true;
        }
    }

    /**
     * @notice authorize upgrade
     * @param newImplementation new implementation address
     * @dev has to be an override function, since it is defined in UUPSUpgradeable
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
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
     * @notice complete direct transfer
     * @param transferData payment or donation arguments
     */
    function completeDirectTransfer(
        TransferData calldata transferData
    ) internal whenNotExpired(transferData.expiry) returns (uint256) {
        // transfer payInToken to contract
        if (IERC20(transferData.payInToken).isETH(transferData.payInAmount) == 0) {
            IERC20(transferData.payInToken).safeTransferFrom(msg.sender, address(this), transferData.payInAmount);
        }

        uint256 feeCollected = transferData.payInAmount - transferData.payOutAmount;

        IERC20(transferData.payInToken).safeTransfer(transferData.merchant, transferData.payOutAmount);

        return feeCollected;
    }

    /**
     * @notice complete payment with direct transfer
     * @param payment payment arguments
     */
    function completeTransferPayment(TransferData calldata payment) external payable whenNotExpired(payment.expiry) {
        uint256 feeCollected = completeDirectTransfer(payment);

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
     * @notice complete donation with direct transfer
     * @param donation donation arguments
     */
    function completeTransferDonation(TransferData calldata donation) external payable {
        uint256 feeCollected = completeDirectTransfer(donation);

        emit DonationCompleted(
            donation.orderId,
            donation.payInToken,
            donation.payInToken,
            donation.payInAmount,
            donation.payOutAmount,
            feeCollected,
            donation.merchant
        );
    }

    /**
     * @notice complete swap transfer
     * @param transferData payment or donation arguments
     * @param swapData swap arguments
     */
    function completeSwapTransfer(
        TransferData calldata transferData,
        SwapData calldata swapData
    ) internal whenNotExpired(transferData.expiry) returns (uint256, uint256) {
        if (!whitelistedSwapProviders[swapData.provider]) {
            revert PaymentErrors.SwapProviderNotWhitelisted();
        }

        (uint256 actualPayInAmount, uint256 receivedPayOutAmount) = executeSwap(transferData, swapData);

        uint256 feeCollected = receivedPayOutAmount - transferData.payOutAmount;

        // transfer payOutToken to merchant
        IERC20(transferData.payOutToken).safeTransfer(transferData.merchant, transferData.payOutAmount);

        // if swap is a BUY, return unused payInAmount to user
        if (swapData.swapType == SwapType.BUY) {
            uint256 unusedPayInAmount = transferData.payInAmount - actualPayInAmount;

            if (unusedPayInAmount > 0) {
                IERC20(transferData.payInToken).safeTransfer(msg.sender, unusedPayInAmount);
            }
        }

        return (actualPayInAmount, feeCollected);
    }

    /**
     * @notice complete payment with swap
     * @param payment payment arguments
     * @param swapData swap arguments
     */
    function completeSwapPayment(
        TransferData calldata payment,
        SwapData calldata swapData
    ) external payable whenNotExpired(payment.expiry) {
        (uint256 actualPayInAmount, uint256 feeCollected) = completeSwapTransfer(payment, swapData);

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
     * @notice complete donation with swap
     * @param donation donation arguments
     * @param swapData swap arguments
     */
    function completeSwapDonation(TransferData calldata donation, SwapData calldata swapData) external payable {
        (uint256 actualPayInAmount, uint256 feeCollected) = completeSwapTransfer(donation, swapData);

        emit DonationCompleted(
            donation.orderId,
            donation.payInToken,
            donation.payOutToken,
            actualPayInAmount,
            donation.payOutAmount,
            feeCollected,
            donation.merchant
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
     * @param transferData payment or donation arguments
     * @param swapData swap arguments
     * @return spent amount of payInToken
     * @return received amount of payOutToken
     */
    function executeSwap(
        TransferData calldata transferData,
        SwapData calldata swapData
    ) internal returns (uint256 spent, uint256 received) {
        if (IERC20(transferData.payInToken).isETH(transferData.payInAmount) == 0) {
            IERC20(transferData.payInToken).safeTransferFrom(msg.sender, address(this), transferData.payInAmount);
            if (swapData.shouldApprove) {
                IERC20(transferData.payInToken).approve(swapData.provider);
            }
        }

        uint256 payInBeforeSwap = IERC20(transferData.payInToken).getBalance(address(this));
        uint256 payOutBeforeSwap = IERC20(transferData.payOutToken).getBalance(address(this));

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

        uint256 payInAfterSwap = IERC20(transferData.payInToken).getBalance(address(this));
        uint256 payOutAfterSwap = IERC20(transferData.payOutToken).getBalance(address(this));

        spent = payInBeforeSwap - payInAfterSwap;
        received = payOutAfterSwap - payOutBeforeSwap;
    }

    /**
     * @notice Fallback function to receive native token
     */
    receive() external payable {}
}
