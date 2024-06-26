// SPDX-License-Identifier: MIT
pragma solidity <0.9.0 >=0.8.11 ^0.8.0 ^0.8.20 ^0.8.24;

// lib/contracts/contracts/interfaces/IPool.sol



interface IPool {
    error DepositsNotEqual();
    error BelowMinimumK();
    error FactoryAlreadySet();
    error InsufficientLiquidity();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error IsPaused();
    error InvalidTo();
    error K();
    error NotEmergencyCouncil();

    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        address indexed to,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);

    // Struct to capture time period obervations every 30 minutes, used for local oracles
    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

    /// @notice Returns the decimal (dec), reserves (r), stable (st), and tokens (t) of token0 and token1
    function metadata()
        external
        view
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);

    /// @notice Claim accumulated but unclaimed fees (claimable0 and claimable1)
    function claimFees() external returns (uint256, uint256);

    /// @notice Returns [token0, token1]
    function tokens() external view returns (address, address);

    /// @notice Address of token in the pool with the lower address value
    function token0() external view returns (address);

    /// @notice Address of token in the poool with the higher address value
    function token1() external view returns (address);

    /// @notice Address of linked PoolFees.sol
    function poolFees() external view returns (address);

    /// @notice Address of PoolFactory that created this contract
    function factory() external view returns (address);

    /// @notice Capture oracle reading every 30 minutes (1800 seconds)
    function periodSize() external view returns (uint256);

    /// @notice Amount of token0 in pool
    function reserve0() external view returns (uint256);

    /// @notice Amount of token1 in pool
    function reserve1() external view returns (uint256);

    /// @notice Timestamp of last update to pool
    function blockTimestampLast() external view returns (uint256);

    /// @notice Cumulative of reserve0 factoring in time elapsed
    function reserve0CumulativeLast() external view returns (uint256);

    /// @notice Cumulative of reserve1 factoring in time elapsed
    function reserve1CumulativeLast() external view returns (uint256);

    /// @notice Accumulated fees of token0 (global)
    function index0() external view returns (uint256);

    /// @notice Accumulated fees of token1 (global)
    function index1() external view returns (uint256);

    /// @notice Get an LP's relative index0 to index0
    function supplyIndex0(address) external view returns (uint256);

    /// @notice Get an LP's relative index1 to index1
    function supplyIndex1(address) external view returns (uint256);

    /// @notice Amount of unclaimed, but claimable tokens from fees of token0 for an LP
    function claimable0(address) external view returns (uint256);

    /// @notice Amount of unclaimed, but claimable tokens from fees of token1 for an LP
    function claimable1(address) external view returns (uint256);

    /// @notice Returns the value of K in the Pool, based on its reserves.
    function getK() external returns (uint256);

    /// @notice Set pool name
    ///         Only callable by Voter.emergencyCouncil()
    /// @param __name String of new name
    function setName(string calldata __name) external;

    /// @notice Set pool symbol
    ///         Only callable by Voter.emergencyCouncil()
    /// @param __symbol String of new symbol
    function setSymbol(string calldata __symbol) external;

    /// @notice Get the number of observations recorded
    function observationLength() external view returns (uint256);

    /// @notice Get the value of the most recent observation
    function lastObservation() external view returns (Observation memory);

    /// @notice True if pool is stable, false if volatile
    function stable() external view returns (bool);

    /// @notice Produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);

    /// @notice Provides twap price with user configured granularity, up to the full window size
    /// @param tokenIn .
    /// @param amountIn .
    /// @param granularity .
    /// @return amountOut .
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);

    /// @notice Returns a memory set of TWAP prices
    ///         Same as calling sample(tokenIn, amountIn, points, 1)
    /// @param tokenIn .
    /// @param amountIn .
    /// @param points Number of points to return
    /// @return Array of TWAP prices
    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory);

    /// @notice Same as prices with with an additional window argument.
    ///         Window = 2 means 2 * 30min (or 1 hr) between observations
    /// @param tokenIn .
    /// @param amountIn .
    /// @param points .
    /// @param window .
    /// @return Array of TWAP prices
    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    ) external view returns (uint256[] memory);

    /// @notice This low-level function should be called from a contract which performs important safety checks
    /// @param amount0Out   Amount of token0 to send to `to`
    /// @param amount1Out   Amount of token1 to send to `to`
    /// @param to           Address to recieve the swapped output
    /// @param data         Additional calldata for flashloans
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice This low-level function should be called from a contract which performs important safety checks
    ///         standard uniswap v2 implementation
    /// @param to Address to receive token0 and token1 from burning the pool token
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice This low-level function should be called by addLiquidity functions in Router.sol, which performs important safety checks
    ///         standard uniswap v2 implementation
    /// @param to           Address to receive the minted LP token
    /// @return liquidity   Amount of LP token minted
    function mint(address to) external returns (uint256 liquidity);

    /// @notice Update reserves and, on the first call per block, price accumulators
    /// @return _reserve0 .
    /// @return _reserve1 .
    /// @return _blockTimestampLast .
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);

    /// @notice Get the amount of tokenOut given the amount of tokenIn
    /// @param amountIn Amount of token in
    /// @param tokenIn  Address of token
    /// @return Amount out
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    /// @notice Force balances to match reserves
    /// @param to Address to receive any skimmed rewards
    function skim(address to) external;

    /// @notice Force reserves to match balances
    function sync() external;

    /// @notice Called on pool creation by PoolFactory
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    /// @param _stable True if stable, false if volatile
    function initialize(address _token0, address _token1, bool _stable) external;
}

// lib/contracts/contracts/interfaces/factories/IPoolFactory.sol



interface IPoolFactory {
    event SetFeeManager(address feeManager);
    event SetPauser(address pauser);
    event SetPauseState(bool state);
    event SetVoter(address voter);
    event PoolCreated(address indexed token0, address indexed token1, bool indexed stable, address pool, uint256);
    event SetCustomFee(address indexed pool, uint256 fee);

    error FeeInvalid();
    error FeeTooHigh();
    error InvalidPool();
    error NotFeeManager();
    error NotPauser();
    error NotVoter();
    error PoolAlreadyExists();
    error SameAddress();
    error ZeroFee();
    error ZeroAddress();

    /// @notice returns the number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Is a valid pool created by this factory.
    /// @param .
    function isPool(address pool) external view returns (bool);

    /// @notice Return address of pool created by this factory
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable True if stable, false if volatile
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);

    /// @notice Support for v3-style pools which wraps around getPool(tokenA,tokenB,stable)
    /// @dev fee is converted to stable boolean.
    /// @param tokenA .
    /// @param tokenB .
    /// @param fee  1 if stable, 0 if volatile, else returns address(0)
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    /// @dev Only called once to set to Voter.sol - Voter does not have a function
    ///      to call this contract method, so once set it's immutable.
    ///      This also follows convention of setVoterAndDistributor() in VotingEscrow.sol
    /// @param _voter .
    function setVoter(address _voter) external;

    function setPauser(address _pauser) external;

    function setPauseState(bool _state) external;

    function setFeeManager(address _feeManager) external;

    /// @notice Set default fee for stable and volatile pools.
    /// @dev Throws if higher than maximum fee.
    ///      Throws if fee is zero.
    /// @param _stable Stable or volatile pool.
    /// @param _fee .
    function setFee(bool _stable, uint256 _fee) external;

    /// @notice Set overriding fee for a pool from the default
    /// @dev A custom fee of zero means the default fee will be used.
    function setCustomFee(address _pool, uint256 _fee) external;

    /// @notice Returns fee for a pool, as custom fees are possible.
    function getFee(address _pool, bool _stable) external view returns (uint256);

    /// @notice Create a pool given two tokens and if they're stable/volatile
    /// @dev token order does not matter
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable .
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);

    /// @notice Support for v3-style pools which wraps around createPool(tokena,tokenB,stable)
    /// @dev fee is converted to stable boolean
    /// @dev token order does not matter
    /// @param tokenA .
    /// @param tokenB .
    /// @param fee 1 if stable, 0 if volatile, else revert
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);

    function isPaused() external view returns (bool);

    function voter() external view returns (address);

    function implementation() external view returns (address);
}

// lib/openzeppelin-contracts/contracts/Token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20_0 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)


/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20_1 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

}

// lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721Receiver.sol)



/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)



/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// src/interfaces/IAccount.sol



/**
 * @title Module for managing accounts.
 * @notice Manages the system's account token NFT. Every user will need to register an account before being able to interact with the system.
 */
interface IAccountModule {
    /**
     * @notice Thrown when the account interacting with the system is expected to be the associated account token, but is not.
     */
    error OnlyAccountTokenProxy(address origin);

    /**
     * @notice Thrown when an account attempts to renounce a permission that it didn't have.
     */
    error PermissionNotGranted(uint128 accountId, bytes32 permission, address user);

    /**
     * @notice Thrown when the requested account ID is greater or equal to type(uint128).max / 2
     */
    error InvalidAccountId(uint128 accountId);

    /**
     * @notice Emitted when an account token with id `accountId` is minted to `sender`.
     * @param accountId The id of the account.
     * @param owner The address that owns the created account.
     */
    event AccountCreated(uint128 indexed accountId, address indexed owner);

    /**
     * @notice Emitted when `user` is granted `permission` by `sender` for account `accountId`.
     * @param accountId The id of the account that granted the permission.
     * @param permission The bytes32 identifier of the permission.
     * @param user The target address to whom the permission was granted.
     * @param sender The Address that granted the permission.
     */
    event PermissionGranted(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender
    );

    /**
     * @notice Emitted when `user` has `permission` renounced or revoked by `sender` for account `accountId`.
     * @param accountId The id of the account that has had the permission revoked.
     * @param permission The bytes32 identifier of the permission.
     * @param user The target address for which the permission was revoked.
     * @param sender The address that revoked the permission.
     */
    event PermissionRevoked(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender
    );

    /**
     * @dev Data structure for tracking each user's permissions.
     */
    struct AccountPermissions {
        /**
         * @dev The address for which all the permissions are granted.
         */
        address user;
        /**
         * @dev The array of permissions given to the associated address.
         */
        bytes32[] permissions;
    }

    /**
     * @notice Returns an array of `AccountPermission` for the provided `accountId`.
     * @param accountId The id of the account whose permissions are being retrieved.
     * @return accountPerms An array of AccountPermission objects describing the permissions granted to the account.
     */
    function getAccountPermissions(
        uint128 accountId
    ) external view returns (AccountPermissions[] memory accountPerms);

    /**
     * @notice Mints an account token with id `requestedAccountId` to `ERC2771Context._msgSender()`.
     * @param requestedAccountId The id requested for the account being created. Reverts if id already exists.
     *
     * Requirements:
     *
     * - `requestedAccountId` must not already be minted.
     * - `requestedAccountId` must be less than type(uint128).max / 2
     *
     * Emits a {AccountCreated} event.
     */
    function createAccount(uint128 requestedAccountId) external;

    /**
     * @notice Mints an account token with an available id to `ERC2771Context._msgSender()`.
     *
     * Emits a {AccountCreated} event.
     */
    function createAccount() external returns (uint128 accountId);

    /**
     * @notice Called by AccountTokenModule to notify the system when the account token is transferred.
     * @dev Resets user permissions and assigns ownership of the account token to the new holder.
     * @param to The new holder of the account NFT.
     * @param accountId The id of the account that was just transferred.
     *
     * Requirements:
     *
     * - `ERC2771Context._msgSender()` must be the account token.
     */
    function notifyAccountTransfer(address to, uint128 accountId) external;

    /**
     * @notice Grants `permission` to `user` for account `accountId`.
     * @param accountId The id of the account that granted the permission.
     * @param permission The bytes32 identifier of the permission.
     * @param user The target address that received the permission.
     *
     * Requirements:
     *
     * - `ERC2771Context._msgSender()` must own the account token with ID `accountId` or have the "admin" permission.
     *
     * Emits a {PermissionGranted} event.
     */
    function grantPermission(uint128 accountId, bytes32 permission, address user) external;

    /**
     * @notice Revokes `permission` from `user` for account `accountId`.
     * @param accountId The id of the account that revoked the permission.
     * @param permission The bytes32 identifier of the permission.
     * @param user The target address that no longer has the permission.
     *
     * Requirements:
     *
     * - `ERC2771Context._msgSender()` must own the account token with ID `accountId` or have the "admin" permission.
     *
     * Emits a {PermissionRevoked} event.
     */
    function revokePermission(uint128 accountId, bytes32 permission, address user) external;

    /**
     * @notice Revokes `permission` from `ERC2771Context._msgSender()` for account `accountId`.
     * @param accountId The id of the account whose permission was renounced.
     * @param permission The bytes32 identifier of the permission.
     *
     * Emits a {PermissionRevoked} event.
     */
    function renouncePermission(uint128 accountId, bytes32 permission) external;

    /**
     * @notice Returns `true` if `user` has been granted `permission` for account `accountId`.
     * @param accountId The id of the account whose permission is being queried.
     * @param permission The bytes32 identifier of the permission.
     * @param user The target address whose permission is being queried.
     * @return hasPermission A boolean with the response of the query.
     */
    function hasPermission(
        uint128 accountId,
        bytes32 permission,
        address user
    ) external view returns (bool hasPermission);

    /**
     * @notice Returns `true` if `target` is authorized to `permission` for account `accountId`.
     * @param accountId The id of the account whose permission is being queried.
     * @param permission The bytes32 identifier of the permission.
     * @param target The target address whose permission is being queried.
     * @return isAuthorized A boolean with the response of the query.
     */
    function isAuthorized(
        uint128 accountId,
        bytes32 permission,
        address target
    ) external view returns (bool isAuthorized);

    /**
     * @notice Returns the address for the account token used by the module.
     * @return accountNftToken The address of the account token.
     */
    function getAccountTokenAddress() external view returns (address accountNftToken);

    /**
     * @notice Returns the address that owns a given account, as recorded by the system.
     * @param accountId The account id whose owner is being retrieved.
     * @return owner The owner of the given account id.
     */
    function getAccountOwner(uint128 accountId) external view returns (address owner);

    /**
     * @notice Returns the last unix timestamp that a permissioned action was taken with this account
     * @param accountId The account id to check
     * @return timestamp The unix timestamp of the last time a permissioned action occured with the account
     */
    function getAccountLastInteraction(uint128 accountId) external view returns (uint256 timestamp);
}

// src/interfaces/ICollateralModule.sol




library CollateralLock {
    struct Data {
        /**
         * @dev The amount of collateral that has been locked.
         */
        uint128 amountD18;
        /**
         * @dev The date when the locked amount becomes unlocked.
         */
        uint64 lockExpirationTime;
    }
}

/**
 * @title Module for managing user collateral.
 * @notice Allows users to deposit and withdraw collateral from the system.
 */
interface ICollateralModule {
    /**
     * @notice Thrown when an interacting account does not have sufficient collateral for an operation (withdrawal, lock, etc).
     */
    error InsufficientAccountCollateral(uint256 amount);

    /**
     * @notice Emitted when `tokenAmount` of collateral of type `collateralType` is deposited to account `accountId` by `sender`.
     * @param accountId The id of the account that deposited collateral.
     * @param collateralType The address of the collateral that was deposited.
     * @param tokenAmount The amount of collateral that was deposited, denominated in the token's native decimal representation.
     * @param sender The address of the account that triggered the deposit.
     */
    event Deposited(
        uint128 indexed accountId,
        address indexed collateralType,
        uint256 tokenAmount,
        address indexed sender
    );

    /**
     * @notice Emitted when a lock is created on someone's account
     * @param accountId The id of the account that received a lock
     * @param collateralType The address of the collateral type that was locked
     * @param tokenAmount The amount of collateral that was locked, demoninated in system units (1e18)
     * @param expireTimestamp unix timestamp at which the lock is due to expire
     */
    event CollateralLockCreated(
        uint128 indexed accountId,
        address indexed collateralType,
        uint256 tokenAmount,
        uint64 expireTimestamp
    );

    /**
     * @notice Emitted when a lock is cleared from an account due to expiration
     * @param accountId The id of the account that has the expired lock
     * @param collateralType The address of the collateral type that was unlocked
     * @param tokenAmount The amount of collateral that was unlocked, demoninated in system units (1e18)
     * @param expireTimestamp unix timestamp at which the unlock is due to expire
     */
    event CollateralLockExpired(
        uint128 indexed accountId,
        address indexed collateralType,
        uint256 tokenAmount,
        uint64 expireTimestamp
    );

    /**
     * @notice Emitted when `tokenAmount` of collateral of type `collateralType` is withdrawn from account `accountId` by `sender`.
     * @param accountId The id of the account that withdrew collateral.
     * @param collateralType The address of the collateral that was withdrawn.
     * @param tokenAmount The amount of collateral that was withdrawn, denominated in the token's native decimal representation.
     * @param sender The address of the account that triggered the withdrawal.
     */
    event Withdrawn(
        uint128 indexed accountId,
        address indexed collateralType,
        uint256 tokenAmount,
        address indexed sender
    );

    /**
     * @notice Deposits `tokenAmount` of collateral of type `collateralType` into account `accountId`.
     * @dev Anyone can deposit into anyone's active account without restriction.
     * @param accountId The id of the account that is making the deposit.
     * @param collateralType The address of the token to be deposited.
     * @param tokenAmount The amount being deposited, denominated in the token's native decimal representation.
     *
     * Emits a {Deposited} event.
     */
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    /**
     * @notice Withdraws `tokenAmount` of collateral of type `collateralType` from account `accountId`.
     * @param accountId The id of the account that is making the withdrawal.
     * @param collateralType The address of the token to be withdrawn.
     * @param tokenAmount The amount being withdrawn, denominated in the token's native decimal representation.
     *
     * Requirements:
     *
     * - `ERC2771Context._msgSender()` must be the owner of the account, have the `ADMIN` permission, or have the `WITHDRAW` permission.
     *
     * Emits a {Withdrawn} event.
     *
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    /**
     * @notice Returns the total values pertaining to account `accountId` for `collateralType`.
     * @param accountId The id of the account whose collateral is being queried.
     * @param collateralType The address of the collateral type whose amount is being queried.
     * @return totalDeposited The total collateral deposited in the account, denominated with 18 decimals of precision.
     * @return totalAssigned The amount of collateral in the account that is delegated to pools, denominated with 18 decimals of precision.
     * @return totalLocked The amount of collateral in the account that cannot currently be undelegated from a pool, denominated with 18 decimals of precision.
     */
    function getAccountCollateral(
        uint128 accountId,
        address collateralType
    ) external view returns (uint256 totalDeposited, uint256 totalAssigned, uint256 totalLocked);

    /**
     * @notice Returns the amount of collateral of type `collateralType` deposited with account `accountId` that can be withdrawn or delegated to pools.
     * @param accountId The id of the account whose collateral is being queried.
     * @param collateralType The address of the collateral type whose amount is being queried.
     * @return amountD18 The amount of collateral that is available for withdrawal or delegation, denominated with 18 decimals of precision.
     */
    function getAccountAvailableCollateral(
        uint128 accountId,
        address collateralType
    ) external view returns (uint256 amountD18);

    /**
     * @notice Clean expired locks from locked collateral arrays for an account/collateral type. It includes offset and items to prevent gas exhaustion. If both, offset and items, are 0 it will traverse the whole array (unlimited).
     * @param accountId The id of the account whose locks are being cleared.
     * @param collateralType The address of the collateral type to clean locks for.
     * @param offset The index of the first lock to clear.
     * @param count The number of slots to check for cleaning locks. Set to 0 to clean all locks at/after offset
     * @return cleared the number of locks that were actually expired (and therefore cleared)
     */
    function cleanExpiredLocks(
        uint128 accountId,
        address collateralType,
        uint256 offset,
        uint256 count
    ) external returns (uint256 cleared);

    /**
     * @notice Get a list of locks existing in account. Lists all locks in storage, even if they are expired
     * @param accountId The id of the account whose locks we want to read
     * @param collateralType The address of the collateral type for locks we want to read
     * @param offset The index of the first lock to read
     * @param count The number of slots to check for cleaning locks. Set to 0 to read all locks after offset
     */
    function getLocks(
        uint128 accountId,
        address collateralType,
        uint256 offset,
        uint256 count
    ) external view returns (CollateralLock.Data[] memory locks);

    /**
     * @notice Create a new lock on the given account. you must have `admin` permission on the specified account to create a lock.
     * @dev Collateral can be withdrawn from the system if it is not assigned or delegated to a pool. Collateral locks are an additional restriction that applies on top of that. I.e. if collateral is not assigned to a pool, but has a lock, it cannot be withdrawn.
     * @dev Collateral locks are initially intended for the Synthetix v2 to v3 migration, but may be used in the future by the Spartan Council, for example, to create and hand off accounts whose withdrawals from the system are locked for a given amount of time.
     * @param accountId The id of the account for which a lock is to be created.
     * @param collateralType The address of the collateral type for which the lock will be created.
     * @param amount The amount of collateral tokens to wrap in the lock being created, denominated with 18 decimals of precision.
     * @param expireTimestamp The date in which the lock will become clearable.
     */
    function createLock(
        uint128 accountId,
        address collateralType,
        uint256 amount,
        uint64 expireTimestamp
    ) external;
}

// src/interfaces/IRewardsManagerModule.sol



/**
 * @title Module for connecting rewards distributors to vaults.
 */
interface IRewardsManagerModule {
    /**
     * @notice Emitted when a reward distributor returns `false` from `payout` indicating a problem
     * preventing the payout from being executed. In this case, it is advised to check with the
     * project maintainers, and possibly try again in the future.
     * @param distributor the distributor which originated the issue
     */
    error RewardUnavailable(address distributor);

    /**
     * @notice Emitted when the pool owner or an existing reward distributor sets up rewards for vault participants.
     * @param poolId The id of the pool on which rewards were distributed.
     * @param collateralType The collateral type of the pool on which rewards were distributed.
     * @param distributor The reward distributor associated to the rewards that were distributed.
     * @param amount The amount of rewards that were distributed.
     * @param start The date one which the rewards will begin to be claimable.
     * @param duration The time in which all of the distributed rewards will be claimable.
     */
    event RewardsDistributed(
        uint128 indexed poolId,
        address indexed collateralType,
        address distributor,
        uint256 amount,
        uint256 start,
        uint256 duration
    );

    /**
     * @notice Emitted when a vault participant claims rewards.
     * @param accountId The id of the account that claimed the rewards.
     * @param poolId The id of the pool where the rewards were claimed.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the rewards distributor associated with these rewards.
     * @param amount The amount of rewards that were claimed.
     */
    event RewardsClaimed(
        uint128 indexed accountId,
        uint128 indexed poolId,
        address indexed collateralType,
        address distributor,
        uint256 amount
    );

    /**
     * @notice Emitted when a new rewards distributor is registered.
     * @param poolId The id of the pool whose reward distributor was registered.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the newly registered reward distributor.
     */
    event RewardsDistributorRegistered(
        uint128 indexed poolId,
        address indexed collateralType,
        address indexed distributor
    );

    /**
     * @notice Emitted when an already registered rewards distributor is removed.
     * @param poolId The id of the pool whose reward distributor was registered.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the registered reward distributor.
     */
    event RewardsDistributorRemoved(
        uint128 indexed poolId,
        address indexed collateralType,
        address indexed distributor
    );

    /**
     * @notice Called by pool owner to register rewards for vault participants.
     * @param poolId The id of the pool whose rewards are to be managed by the specified distributor.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the reward distributor to be registered.
     */
    function registerRewardsDistributor(
        uint128 poolId,
        address collateralType,
        address distributor
    ) external;

    /**
     * @notice Called by pool owner to remove a registered rewards distributor for vault participants.
     * WARNING: if you remove a rewards distributor, the same address can never be re-registered again. If you
     * simply want to turn off
     * rewards, call `distributeRewards` with 0 emission. If you need to completely reset the rewards distributor
     * again, create a new rewards distributor at a new address and register the new one.
     * This function is provided since the number of rewards distributors added to an account is finite,
     * so you can remove an unused rewards distributor if need be.
     * NOTE: unclaimed rewards can still be claimed after a rewards distributor is removed (though any
     * rewards-over-time will be halted)
     * @param poolId The id of the pool whose rewards are to be managed by the specified distributor.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the reward distributor to be registered.
     */
    function removeRewardsDistributor(
        uint128 poolId,
        address collateralType,
        address distributor
    ) external;

    /**
     * @notice Called by a registered distributor to set up rewards for vault participants.
     * @dev Will revert if the caller is not a registered distributor.
     * @param poolId The id of the pool to distribute rewards to.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param amount The amount of rewards to be distributed.
     * @param start The date at which the rewards will begin to be claimable.
     * @param duration The period after which all distributed rewards will be claimable.
     */
    function distributeRewards(
        uint128 poolId,
        address collateralType,
        uint256 amount,
        uint64 start,
        uint32 duration
    ) external;

    /**
     * @notice Called by owner of a pool to set rewards for vault participants. This method
     * of reward setting is generally intended to only be used to recover from a case where the
     * distributor state is out of sync with the core system state, or if the distributor is only
     * able to payout and not capable of distributing its own rewards.
     * @dev Will revert if the caller is not the owner of the pool.
     * @param poolId The id of the pool to distribute rewards to.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param rewardsDistributor The address of the reward distributor which pays out the tokens.
     * @param amount The amount of rewards to be distributed.
     * @param start The date at which the rewards will begin to be claimable.
     * @param duration The period after which all distributed rewards will be claimable.
     */
    function distributeRewardsByOwner(
        uint128 poolId,
        address collateralType,
        address rewardsDistributor,
        uint256 amount,
        uint64 start,
        uint32 duration
    ) external;

    /**
     * @notice Allows a user with appropriate permissions to claim rewards associated with a position.
     * @param accountId The id of the account that is to claim the rewards.
     * @param poolId The id of the pool to claim rewards on.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the rewards distributor associated with the rewards being claimed.
     * @return amountClaimedD18 The amount of rewards that were available for the account and thus claimed.
     */
    function claimRewards(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        address distributor
    ) external returns (uint256 amountClaimedD18);

    /**
     * @notice For a given position, return the rewards that can currently be claimed.
     * @param poolId The id of the pool being queried.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param accountId The id of the account whose available rewards are being queried.
     * @return claimableD18 An array of ids of the reward entries that are claimable by the position.
     * @return distributors An array with the addresses of the reward distributors associated with the claimable rewards.
     */
    function updateRewards(
        uint128 poolId,
        address collateralType,
        uint128 accountId
    ) external returns (uint256[] memory claimableD18, address[] memory distributors);

    /**
     * @notice Returns the number of individual units of amount emitted per second per share for the given poolId, collateralType, distributor vault.
     * @param poolId The id of the pool being queried.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the rewards distributor associated with the rewards in question.
     * @return rateD18 The queried rewards rate.
     */
    function getRewardRate(
        uint128 poolId,
        address collateralType,
        address distributor
    ) external view returns (uint256 rateD18);

    /**
     * @notice Returns the amount of claimable rewards for a given accountId for a vault distributor.
     * @param accountId The id of the account to look up rewards on.
     * @param poolId The id of the pool to claim rewards on.
     * @param collateralType The address of the collateral used in the pool's rewards.
     * @param distributor The address of the rewards distributor associated with the rewards being claimed.
     * @return rewardAmount The amount of available rewards that are available for the provided account.
     */
    function getAvailableRewards(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        address distributor
    ) external view returns (uint256 rewardAmount);
}

// src/interfaces/IVault.sol




/**
 * @title Allows accounts to delegate collateral to a pool.
 * @dev Delegation updates the account's position in the vault that corresponds to the associated pool and collateral type pair.
 * @dev A pool contains one vault for each collateral type it supports, and vaults are not shared between pools.
 */
interface IVaultModule {
    /**
     * @notice Thrown when attempting to delegate collateral to a vault with a leverage amount that is not supported by the system.
     */
    error InvalidLeverage(uint256 leverage);

    /**
     * @notice Thrown when attempting to delegate collateral to a market whose capacity is locked.
     */
    error CapacityLocked(uint256 marketId);

    /**
     * @notice Thrown when the specified new collateral amount to delegate to the vault equals the current existing amount.
     */
    error InvalidCollateralAmount();

    /**
     * @notice Emitted when {sender} updates the delegation of collateral in the specified liquidity position.
     * @param accountId The id of the account whose position was updated.
     * @param poolId The id of the pool in which the position was updated.
     * @param collateralType The address of the collateral associated to the position.
     * @param amount The new amount of the position, denominated with 18 decimals of precision.
     * @param leverage The new leverage value of the position, denominated with 18 decimals of precision.
     * @param sender The address that triggered the update of the position.
     */
    event DelegationUpdated(
        uint128 indexed accountId,
        uint128 indexed poolId,
        address collateralType,
        uint256 amount,
        uint256 leverage,
        address indexed sender
    );

    /**
     * @notice Updates an account's delegated collateral amount for the specified pool and collateral type pair.
     * @param accountId The id of the account associated with the position that will be updated.
     * @param poolId The id of the pool associated with the position.
     * @param collateralType The address of the collateral used in the position.
     * @param amount The new amount of collateral delegated in the position, denominated with 18 decimals of precision.
     * @param leverage The new leverage amount used in the position, denominated with 18 decimals of precision.
     *
     * Requirements:
     *
     * - `ERC2771Context._msgSender()` must be the owner of the account, have the `ADMIN` permission, or have the `DELEGATE` permission.
     * - If increasing the amount delegated, it must not exceed the available collateral (`getAccountAvailableCollateral`) associated with the account.
     * - If decreasing the amount delegated, the liquidity position must have a collateralization ratio greater than the target collateralization ratio for the corresponding collateral type.
     *
     * Emits a {DelegationUpdated} event.
     */
    function delegateCollateral(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        uint256 amount,
        uint256 leverage
    ) external;

    /**
     * @notice Returns the collateralization ratio of the specified liquidity position. If debt is negative, this function will return 0.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @dev The return value is a percentage with 18 decimals places.
     * @param accountId The id of the account whose collateralization ratio is being queried.
     * @param poolId The id of the pool in which the account's position is held.
     * @param collateralType The address of the collateral used in the queried position.
     * @return ratioD18 The collateralization ratio of the position (collateral / debt), denominated with 18 decimals of precision.
     */
    function getPositionCollateralRatio(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    ) external returns (uint256 ratioD18);

    /**
     * @notice Returns the debt of the specified liquidity position. Credit is expressed as negative debt.
     * @dev This is not a view function, and actually updates the entire debt distribution chain.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @param accountId The id of the account being queried.
     * @param poolId The id of the pool in which the account's position is held.
     * @param collateralType The address of the collateral used in the queried position.
     * @return debtD18 The amount of debt held by the position, denominated with 18 decimals of precision.
     */
    function getPositionDebt(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    ) external returns (int256 debtD18);

    /**
     * @notice Returns the amount of the collateral associated with the specified liquidity position.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @dev collateralAmount is represented as an integer with 18 decimals.
     * @param accountId The id of the account being queried.
     * @param poolId The id of the pool in which the account's position is held.
     * @param collateralType The address of the collateral used in the queried position.
     * @return collateralAmountD18 The amount of collateral used in the position, denominated with 18 decimals of precision.
     */
    function getPositionCollateral(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    ) external view returns (uint256 collateralAmountD18);

    /**
     * @notice Returns all information pertaining to a specified liquidity position in the vault module.
     * @param accountId The id of the account being queried.
     * @param poolId The id of the pool in which the account's position is held.
     * @param collateralType The address of the collateral used in the queried position.
     * @return collateralAmountD18 The amount of collateral used in the position, denominated with 18 decimals of precision.
     * @return collateralValueD18 The value of the collateral used in the position, denominated with 18 decimals of precision.
     * @return debtD18 The amount of debt held in the position, denominated with 18 decimals of precision.
     * @return collateralizationRatioD18 The collateralization ratio of the position (collateral / debt), denominated with 18 decimals of precision.
     **/
    function getPosition(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        external
        returns (
            uint256 collateralAmountD18,
            uint256 collateralValueD18,
            int256 debtD18,
            uint256 collateralizationRatioD18
        );

    /**
     * @notice Returns the total debt (or credit) that the vault is responsible for. Credit is expressed as negative debt.
     * @dev This is not a view function, and actually updates the entire debt distribution chain.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @param poolId The id of the pool that owns the vault whose debt is being queried.
     * @param collateralType The address of the collateral of the associated vault.
     * @return debtD18 The overall debt of the vault, denominated with 18 decimals of precision.
     **/
    function getVaultDebt(uint128 poolId, address collateralType) external returns (int256 debtD18);

    /**
     * @notice Returns the amount and value of the collateral held by the vault.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @dev collateralAmount is represented as an integer with 18 decimals.
     * @dev collateralValue is represented as an integer with the number of decimals specified by the collateralType.
     * @param poolId The id of the pool that owns the vault whose collateral is being queried.
     * @param collateralType The address of the collateral of the associated vault.
     * @return collateralAmountD18 The collateral amount of the vault, denominated with 18 decimals of precision.
     * @return collateralValueD18 The collateral value of the vault, denominated with 18 decimals of precision.
     */
    function getVaultCollateral(
        uint128 poolId,
        address collateralType
    ) external view returns (uint256 collateralAmountD18, uint256 collateralValueD18);

    /**
     * @notice Returns the collateralization ratio of the vault. If debt is negative, this function will return 0.
     * @dev Call this function using `callStatic` to treat it as a view function.
     * @dev The return value is a percentage with 18 decimals places.
     * @param poolId The id of the pool that owns the vault whose collateralization ratio is being queried.
     * @param collateralType The address of the collateral of the associated vault.
     * @return ratioD18 The collateralization ratio of the vault, denominated with 18 decimals of precision.
     */
    function getVaultCollateralRatio(
        uint128 poolId,
        address collateralType
    ) external returns (uint256 ratioD18);
}

// src/interfaces/IWrapperModule.sol



/**
 * @title Module for synth wrappers
 */
interface IWrapperModule {


    struct Data {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    /**
     * @notice Wraps the specified amount and returns similar value of synth minus the fees.
     * @dev Fees are collected from the user by way of the contract returning less synth than specified amount of collateral.
     * @param marketId Id of the market used for the trade.
     * @param wrapAmount Amount of collateral to wrap.  This amount gets deposited into the market collateral manager.
     * @param minAmountReceived The minimum amount of synths the trader is expected to receive, otherwise the transaction will revert.
     * @return amountToMint Amount of synth returned to user.
     * @return fees breakdown of all fees. in this case, only wrapper fees are returned.
     */
    function wrap(
        uint128 marketId,
        uint256 wrapAmount,
        uint256 minAmountReceived
    ) external returns (uint256 amountToMint, Data memory fees);

    /**
     * @notice Unwraps the synth and returns similar value of collateral minus the fees.
     * @dev Transfers the specified synth, collects fees through configured fee collector, returns collateral minus fees to trader.
     * @param marketId Id of the market used for the trade.
     * @param unwrapAmount Amount of synth trader is unwrapping.
     * @param minAmountReceived The minimum amount of collateral the trader is expected to receive, otherwise the transaction will revert.
     * @return returnCollateralAmount Amount of collateral returned.
     * @return fees breakdown of all fees. in this case, only wrapper fees are returned.
     */
    function unwrap(
        uint128 marketId,
        uint256 unwrapAmount,
        uint256 minAmountReceived
    ) external returns (uint256 returnCollateralAmount, Data memory fees);
}

// src/interfaces/types/IHippodromeTypes.sol



interface IHippodromeTypes {
    struct Campaign{
        address founder;//═════════════════════════════╗ 
        uint96  poolSupply;//══════════════════════════╝
        address tokenAddress;//════════════════════════╗ 
        uint256  currentStake;//════════════════════════╝ 
        address poolAddress;//═════════════════════════╗ 
        uint256  raised;//══════════════════════════════╝ 
        uint88  startTimestamp;//══════════════════════╗ 
        uint88  endTimestamp;//════════════════════════╝ 
        uint88  unvestStart;//═════════════════════════╗ 
        uint88  unvestEnd;//═══════════════════════════╝ 
        uint96  rewardSupply;
        string  campaignURI; 
    }

    struct CampaignParams{
        uint96  poolSupply; 
        uint88  startTimestamp;  
        uint88  endTimestamp;
        uint88  unvestingStreamStart;
        uint88  unvestingStreamEnd;
        uint96  rewardSupply;
        address tokenAddress;
        string  campaignURI;
    }

    struct UserStake {
        uint256 amount;
        uint256 lastStakeTime;
        uint256 totalContribution;
    }
    
    struct Launch {
        mapping(address => UserStake) userStakes;
        uint256 totalStaked;
        uint256 totalContribution;
        uint256 lastUpdateTime;
    }
} 

// lib/contracts/contracts/interfaces/IWETH.sol





interface IWETH is IERC20_1 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

// lib/openzeppelin-contracts/contracts/Token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)





/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20_0 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// src/interfaces/IHippodrome.sol





interface IHippodrome is IHippodromeTypes{
    
    event CampaignCreated(uint indexed campaignID, address indexed founder, Campaign campaign);
    event FundsAdded(uint indexed campaignID, address indexed user, uint amount);
    event FundsWithdrawed(uint indexed campaignID, address indexed user, uint amount);
    event CampaignTerminated(uint campaignID, uint raised);
    event RewardsClaimed(uint indexed campaignID, address indexed user, uint amount);
    
    error CampaignNotActive();
    error WithdrawLocked(uint256 unlockTime);
    error RewardsAlreadyClaimed();
    error CampaignAlreadyExist();
    // other errors 

    function createCampaign(CampaignParams memory campaignParams) external  returns(uint128 accountID);
    function fundCampaign(uint128 campaignId, uint amount) external ;
    function withdrawFunds(uint128 campaign, uint amount) external ;
    function claimRewards(uint128 campaignID) external ;
    function resolveCampaign(uint128 campaignID) external ;

    function getCampaign(uint) external view returns (
        address, uint96, address, uint, address, uint, uint88, uint88, uint88, uint88, uint96, string memory
    );
    function getCampaignTokenInfos(uint) external view returns(string memory, string memory);
    function getAvailableUserRewards(address user, uint128 campaignID) external view  returns (uint);
    function calculateContributionPercentage(uint128 campaignID, address user) external view  returns (uint);
    function getUserRewardStatus(uint128 campaignID, address user) external view  returns(uint, uint);
    function getCampaignAccountId(uint) external view returns(uint128);
    function getUserStake(address user, uint128 campaignID) external view returns(uint);

}

// lib/contracts/contracts/interfaces/IRouter.sol





interface IRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    error ETHTransferFailed();
    error Expired();
    error InsufficientAmount();
    error InsufficientAmountA();
    error InsufficientAmountB();
    error InsufficientAmountADesired();
    error InsufficientAmountBDesired();
    error InsufficientAmountAOptimal();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidAmountInForETHDeposit();
    error InvalidTokenInForETHDeposit();
    error InvalidPath();
    error InvalidRouteA();
    error InvalidRouteB();
    error OnlyWETH();
    error PoolDoesNotExist();
    error PoolFactoryDoesNotExist();
    error SameAddresses();
    error ZeroAddress();

    /// @notice Address of FactoryRegistry.sol
    function factoryRegistry() external view returns (address);

    /// @notice Address of Protocol PoolFactory.sol
    function defaultFactory() external view returns (address);

    /// @notice Address of Voter.sol
    function voter() external view returns (address);

    /// @notice Interface of WETH contract used for WETH => ETH wrapping/unwrapping
    function weth() external view returns (IWETH);

    /// @dev Represents Ether. Used by zapper to determine whether to return assets as ETH/WETH.
    function ETHER() external view returns (address);

    /// @dev Struct containing information necessary to zap in and out of pools
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           Stable or volatile pool
    /// @param factory          factory of pool
    /// @param amountOutMinA    Minimum amount expected from swap leg of zap via routesA
    /// @param amountOutMinB    Minimum amount expected from swap leg of zap via routesB
    /// @param amountAMin       Minimum amount of tokenA expected from liquidity leg of zap
    /// @param amountBMin       Minimum amount of tokenB expected from liquidity leg of zap
    struct Zap {
        address tokenA;
        address tokenB;
        bool stable;
        address factory;
        uint256 amountOutMinA;
        uint256 amountOutMinB;
        uint256 amountAMin;
        uint256 amountBMin;
    }

    /// @notice Sort two tokens by which address value is less than the other
    /// @param tokenA   Address of token to sort
    /// @param tokenB   Address of token to sort
    /// @return token0  Lower address value between tokenA and tokenB
    /// @return token1  Higher address value between tokenA and tokenB
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    /// @notice Calculate the address of a pool by its' factory.
    ///         Used by all Router functions containing a `Route[]` or `_factory` argument.
    ///         Reverts if _factory is not approved by the FactoryRegistry
    /// @dev Returns a randomly generated address for a nonexistent pool
    /// @param tokenA   Address of token to query
    /// @param tokenB   Address of token to query
    /// @param stable   True if pool is stable, false if volatile
    /// @param _factory Address of factory which created the pool
    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool);

    /// @notice Fetch and sort the reserves for a pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @return reserveA    Amount of reserves of the sorted token A
    /// @return reserveB    Amount of reserves of the sorted token B
    function getReserves(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (uint256 reserveA, uint256 reserveB);

    /// @notice Perform chained getAmountOut calculations on any number of pools
    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    // **** ADD LIQUIDITY ****

    /// @notice Quote the amount deposited into a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param _factory         Address of PoolFactory for tokenA and tokenB
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount of liquidity removed from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @param liquidity    Amount of liquidity to remove
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

    /// @notice Add liquidity of two tokens to a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @param amountAMin       Minimum amount of tokenA to deposit
    /// @param amountBMin       Minimum amount of tokenB to deposit
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Add liquidity of a token and WETH (transferred as ETH) to a Pool
    /// @param token                .
    /// @param stable               True if pool is stable, false if volatile
    /// @param amountTokenDesired   Amount of token desired to deposit
    /// @param amountTokenMin       Minimum amount of token to deposit
    /// @param amountETHMin         Minimum amount of ETH to deposit
    /// @param to                   Recipient of liquidity token
    /// @param deadline             Deadline to add liquidity
    /// @return amountToken         Amount of token to actually deposit
    /// @return amountETH           Amount of tokenETH to actually deposit
    /// @return liquidity           Amount of liquidity token returned from deposit
    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    // **** REMOVE LIQUIDITY ****

    /// @notice Remove liquidity of two tokens from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param liquidity    Amount of liquidity to remove
    /// @param amountAMin   Minimum amount of tokenA to receive
    /// @param amountBMin   Minimum amount of tokenB to receive
    /// @param to           Recipient of tokens received
    /// @param deadline     Deadline to remove liquidity
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Remove liquidity of a token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountToken     Amount of token received
    /// @return amountETH       Amount of ETH received
    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /// @notice Remove liquidity of a fee-on-transfer token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountETH       Amount of ETH received
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    // **** SWAP ****

    /// @notice Swap one token for another
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap ETH for a token
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap a token for WETH (returned as ETH)
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap one token for another without slippage protection
    /// @return amounts     Array of amounts to swap  per route
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function UNSAFE_swapExactTokensForTokens(
        uint256[] memory amounts,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    // **** SWAP (supporting fee-on-transfer tokens) ****

    /// @notice Swap one token for another supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Swap ETH for a token supporting fee-on-transfer tokens
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;

    /// @notice Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the initial swap.
    ///         Additional slippage may be required when adding liquidity as the
    ///         price of the token may have changed.
    /// @param tokenIn      Token you are zapping in from (i.e. input token).
    /// @param amountInA    Amount of input token you wish to send down routesA
    /// @param amountInB    Amount of input token you wish to send down routesB
    /// @param zapInPool    Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert input token to tokenA
    /// @param routesB      Route used to convert input token to tokenB
    /// @param to           Address you wish to mint liquidity to.
    /// @param stake        Auto-stake liquidity in corresponding gauge.
    /// @return liquidity   Amount of LP tokens created from zapping in.
    function zapIn(
        address tokenIn,
        uint256 amountInA,
        uint256 amountInB,
        Zap calldata zapInPool,
        Route[] calldata routesA,
        Route[] calldata routesB,
        address to,
        bool stake
    ) external payable returns (uint256 liquidity);

    /// @notice Zap out a pool (B, C) into A.
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the removal of liquidity.
    ///         Additional slippage may be required on the swap as the
    ///         price of the token may have changed.
    /// @param tokenOut     Token you are zapping out to (i.e. output token).
    /// @param liquidity    Amount of liquidity you wish to remove.
    /// @param zapOutPool   Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert tokenA into output token.
    /// @param routesB      Route used to convert tokenB into output token.
    function zapOut(
        address tokenOut,
        uint256 liquidity,
        Zap calldata zapOutPool,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external;

    /// @notice Used to generate params required for zapping in.
    ///         Zap in => remove liquidity then swap.
    ///         Apply slippage to expected swap values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap in from.
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param amountInA        Amount of input token you wish to send down routesA
    /// @param amountInB        Amount of input token you wish to send down routesB
    /// @param routesA          Route used to convert input token to tokenA
    /// @param routesB          Route used to convert input token to tokenB
    /// @return amountOutMinA   Minimum output expected from swapping input token to tokenA.
    /// @return amountOutMinB   Minimum output expected from swapping input token to tokenB.
    /// @return amountAMin      Minimum amount of tokenA expected from depositing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from depositing liquidity.
    function generateZapInParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountInA,
        uint256 amountInB,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used to generate params required for zapping out.
    ///         Zap out => swap then add liquidity.
    ///         Apply slippage to expected liquidity values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap out of.
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param liquidity        Amount of liquidity being zapped out of into a given output token.
    /// @param routesA          Route used to convert tokenA into output token.
    /// @param routesB          Route used to convert tokenB into output token.
    /// @return amountOutMinA   Minimum output expected from swapping tokenA into output token.
    /// @return amountOutMinB   Minimum output expected from swapping tokenB into output token.
    /// @return amountAMin      Minimum amount of tokenA expected from withdrawing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from withdrawing liquidity.
    function generateZapOutParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.
    /// @dev Returns stable liquidity ratio of B to (A + B).
    ///      E.g. if ratio is 0.4, it means there is more of A than there is of B.
    ///      Therefore you should deposit more of token A than B.
    /// @param tokenA   tokenA of stable pool you are zapping into.
    /// @param tokenB   tokenB of stable pool you are zapping into.
    /// @param factory  Factory that created stable pool.
    /// @return ratio   Ratio of token0 to token1 required to deposit into zap.
    function quoteStableLiquidityRatio(
        address tokenA,
        address tokenB,
        address factory
    ) external view returns (uint256 ratio);
}

// lib/openzeppelin-contracts/contracts/Token/ERC20/ERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)








/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20_0, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// src/MockLiquidityToken.sol





contract MockLiquidityToken is ERC20 {
    error MockLiquidityToken__CallerIsNotProtocol();

    address immutable public i_protocol;

    modifier onlyProtocol {
        if(msg.sender != i_protocol){
            
            revert MockLiquidityToken__CallerIsNotProtocol();
        }
        _;
    }
    constructor() ERC20("MockLiquidityToken", "MLT") {
        i_protocol = msg.sender;
    }

    function mint(uint256 amount) external onlyProtocol{
        _mint(msg.sender, amount);
    }
}

// src/Hippodrome.sol



















// this contract is an hackaton project which isnt production ready
// avoid deploying this contract on mainnet

contract Hippodrome is IERC721Receiver, IHippodrome {
    address internal fUSDC;
    uint8   internal _poolID = 1;
    uint24  internal contributionPrecision = 1e5; 
    
    address internal synthCoreProxy;
    address internal wrapProxy;
    address internal sUSDC;
    address internal aerodromePoolFactory;
    address internal aerodromeRouter;
    address internal mockLiquidityToken;
    uint public _campaignCounter; 

    mapping(uint => Campaign) internal s_campaigns;
    mapping(uint => uint128) internal s_campaignAccounts;
    mapping(address => mapping(uint128 => uint256)) internal s_userStakes;
    mapping(address => mapping(uint128 => uint256)) internal s_contributions;
    mapping(uint256 => Launch) internal s_launches;
    mapping(address => bool) internal s_tokens;
    mapping(address => mapping(uint128 => uint256)) internal s_claims;
    mapping(address => mapping(uint128 => uint256)) internal s_depositTimestamps;
    mapping(uint128 => bool) internal s_campaignResolved;

    modifier onlyActiveCampaign(uint128 campaignID) {
        if (
            !(block.timestamp >= s_campaigns[campaignID].startTimestamp &&
                block.timestamp <= s_campaigns[campaignID].endTimestamp)
        ) {
            revert CampaignNotActive();
        }
        _;
    }

    constructor(
        address _synthCoreProxy,
        address _fUSDC,
        address _wrapModule,
        address _sUSDC,
        address _aerodromePoolFactory,
        address _aerodromeRouter
    ) {
        synthCoreProxy = _synthCoreProxy;
        fUSDC = _fUSDC;
        wrapProxy = _wrapModule;
        sUSDC = _sUSDC;
        aerodromePoolFactory = _aerodromePoolFactory;
        aerodromeRouter = _aerodromeRouter;

        MockLiquidityToken mlt = new MockLiquidityToken();
        mockLiquidityToken = address(mlt);
    }

    //║══════════════════════════════════════════╗
    //║             USER FUNCTIONS               ║
    //║══════════════════════════════════════════╝

    function createCampaign(
        CampaignParams memory campaignParams
    ) external override returns (uint128 accountID) {
        if (s_tokens[campaignParams.tokenAddress])
            revert CampaignAlreadyExist();
        ++_campaignCounter;
        accountID = _createContractAndAccount(campaignParams);
    }

    function fundCampaign(
        uint128 campaignID,
        uint amount
    ) external override onlyActiveCampaign(campaignID) {
        s_userStakes[msg.sender][campaignID] += amount;
        _depositAndDelegateOnAccount(campaignID, amount);
        emit FundsAdded(campaignID, msg.sender, amount);
    }

    function withdrawFunds(
        uint128 campaignID,
        uint amount
    ) external override onlyActiveCampaign(campaignID) {
        // require(
        //     s_depositTimestamps[msg.sender][campaignID] < 10 days,
        //     "Synthetix claim period isn't  over"
        // );
        _claimUserCollateral(campaignID, msg.sender, amount);
        s_userStakes[msg.sender][campaignID] -= amount;
        
        emit FundsWithdrawed(campaignID, msg.sender, amount);
    }

    function claimRewards(uint128 campaignID) external override {
        uint rewards = _getUserRewards(msg.sender, campaignID);
        uint256 stake = s_userStakes[msg.sender][campaignID];
        if (stake > 0){
            IERC20_0(fUSDC).transfer(msg.sender, stake);
            delete s_userStakes[msg.sender][campaignID];
        }
        require(
            rewards > s_claims[msg.sender][campaignID],
            "Hippodrome: claimed"
        );
        Campaign memory campaign = s_campaigns[campaignID];
        
        uint128 accountID = s_campaignAccounts[campaignID];
        IERC20_0(campaign.tokenAddress).transfer(msg.sender, rewards);
        s_claims[msg.sender][campaignID] = rewards;
        
        emit RewardsClaimed(campaignID, msg.sender, rewards);

    }

    // either make it callable by anyone or automate
    function resolveCampaign(uint128 campaignID) external override {
        require(block.timestamp > s_campaigns[campaignID].endTimestamp && !s_campaignResolved[campaignID],
        "Hippodrome: Campaign already solved");
        Campaign memory campaign = s_campaigns[campaignID];

        _claimSynthetixRewards(campaignID);
        campaign.poolAddress = _createAerodromePoolAndAddLiquidity(
            campaign.tokenAddress,
            campaign.raised,
            campaign.poolSupply
        );
        s_campaignResolved[campaignID] = true;

        emit CampaignTerminated(campaignID,  campaign.raised);
    }
    
 
    //║═════════════════════════════════════════╗
    //║             VIEW FUNCTIONS              ║
    //║═════════════════════════════════════════╝

    function getUserStake(address user, uint128 campaignID) external view override returns(uint){
        return s_userStakes[user][campaignID];
    }

    function getAvailableUserRewards(
        address user,
        uint128 campaignID
    ) external view override returns (uint rewards) {
        _getUserRewards(user, campaignID);
    }

    function calculateContributionPercentage(
        uint128 campaignID,
        address user
    ) external view override returns (uint256 percentage) {
        _calculateContributionPercentage(campaignID, user);
    }

    function getUserRewardStatus(
        uint128 campaignID,
        address user
    ) external view override returns (uint totalUserRewards, uint claimed) {
        uint contributionPercentage = _calculateContributionPercentage(
            campaignID,
            user
        );
        Campaign memory campaign = s_campaigns[campaignID];
        totalUserRewards =
            (uint(campaign.rewardSupply) * contributionPercentage) /
            contributionPrecision;
        claimed = s_claims[user][campaignID];
    }

    function getCampaignTokenInfos(uint campaignID) external view override returns (string memory name, string memory symbol) {
        Campaign memory campaign = s_campaigns[campaignID];
        return (
            IERC20Metadata(campaign.tokenAddress).name(),
            IERC20Metadata(campaign.tokenAddress).symbol()
        );
    }

    function getCampaign(uint campaignID) external view override returns (
        address, uint96, address, uint, address, uint, uint88, uint88, uint88, uint88, uint96, string memory
    ) {
        Campaign memory campaign = s_campaigns[campaignID];
        return (
            campaign.founder, 
            campaign.poolSupply, 
            campaign.tokenAddress, 
            campaign.currentStake,
            campaign.poolAddress,
            campaign.raised,
            campaign.startTimestamp, 
            campaign.endTimestamp, 
            campaign.unvestStart,
            campaign.unvestEnd,
            campaign.rewardSupply,
            campaign.campaignURI
        );
    }
    
    function getCampaignAccountId(uint campaignID) public view override returns(uint128 accountID){
        accountID = s_campaignAccounts[campaignID];
    }

    //║═════════════════════════════════════════╗
    //║          internal FUNCTIONS             ║
    //║═════════════════════════════════════════╝

    function _calculateContributionPercentage(
        uint128 campaignID,
        address user
    ) internal view returns (uint256 percentage) {
        uint256 userContribution = _getUserContribution(campaignID, user);
        uint256 totalContribution = _getTotalContribution(campaignID);

        require(
            totalContribution > 0,
            "Total contribution must be greater than zero"
        );
        percentage =
            (userContribution * contributionPrecision) /
            totalContribution;
    }

    function _getUserRewards(
        address user,
        uint128 campaignID
    ) internal view returns (uint rewards) {
        uint contributionPercentage = _calculateContributionPercentage(
            campaignID,
            user
        );
        Campaign memory campaign = s_campaigns[campaignID];
        uint streamStart = campaign.unvestStart;
        uint streamEnd = campaign.unvestEnd;
        uint currentTime = block.timestamp;

        if (currentTime < streamStart) {
            return 0;
        } else if (currentTime > streamEnd) {
            currentTime = streamEnd;
        }

        uint totalUserRewards = (uint(campaign.rewardSupply) *
            contributionPercentage) / contributionPrecision;

        uint elapsedTime = currentTime - streamStart;
        uint streamDuration = streamEnd - streamStart;

        uint claimedRewards = s_claims[user][campaignID];

        rewards =
            ((totalUserRewards * elapsedTime) / streamDuration) -
            claimedRewards;
    }

    function _createContractAndAccount(
        CampaignParams memory campaignParams
    ) internal returns (uint128 accountID) {
        // get tokens from founder
        address campaignToken = campaignParams.tokenAddress;
        uint allocatedSupply = campaignParams.poolSupply +
            campaignParams.rewardSupply;
        IERC20_0(campaignToken).transferFrom(
            msg.sender,
            address(this),
            allocatedSupply
        );

        // create Synthetix Account
        accountID = IAccountModule(synthCoreProxy).createAccount();
        // map the id
        s_campaignAccounts[_campaignCounter] = accountID;
        // map the campaign params
        s_campaigns[_campaignCounter] = Campaign(
            msg.sender,
            campaignParams.poolSupply,
            campaignToken,
            0,
            address(0),
            0,
            campaignParams.startTimestamp,
            campaignParams.endTimestamp,
            campaignParams.unvestingStreamStart,
            campaignParams.unvestingStreamEnd,
            campaignParams.rewardSupply,
            campaignParams.campaignURI
        );

        s_tokens[campaignParams.tokenAddress] = true;
        emit CampaignCreated(
            _campaignCounter,
            msg.sender,
            s_campaigns[_campaignCounter]
        );
    }

    function _depositAndDelegateOnAccount(
        uint128 campaignID,
        uint amount
    ) internal {
        uint128 accountID = s_campaignAccounts[campaignID];
        address memoryFUsdc = fUSDC;
        address memorySUsdc = sUSDC;
        IERC20_0(memoryFUsdc).transferFrom(msg.sender, address(this), amount);

        // wrap
        IERC20_0(memoryFUsdc).approve(wrapProxy, amount);
        IWrapperModule(wrapProxy).wrap(1, amount, 0); // from 6 decimals to 18
        

        // deposit
        uint256 adjustedAmount =  amount* 1e12;
        IERC20_0(memorySUsdc).approve(synthCoreProxy, adjustedAmount);
        ICollateralModule(synthCoreProxy).deposit(accountID, memorySUsdc,  adjustedAmount);

        // make esteem of apy and mint some mockERC20 to use as liquidity 
        // apy is mocked at 20%
        // unfortunately synthetix delegate function has some very-hard-to-debug-solidity-code-and-errors so we can only mock that
        // nontheless testnet would require a simulation environemt, as it may easyly return negative apy. So we opted for a mock
        // the following replace delegate from synthetix
        uint256 amountToMint = (adjustedAmount * 20) / 100;
        MockLiquidityToken(mockLiquidityToken).mint(amountToMint);

        s_campaigns[campaignID].currentStake += uint256(amount);
        s_campaigns[campaignID].raised += uint256(amountToMint);

        _updateAddContribution(msg.sender, campaignID, amount);
    }


    function _claimSynthetixRewards(
        uint campaignID
    )
        internal
        returns (uint256[] memory claimableD18, address[] memory distributors)
    {
        // 10 days on synthetix before claim is available
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        (claimableD18, distributors) = IRewardsManagerModule(synthCoreProxy)
            .updateRewards(_poolID, sUSDC, accountID);
        s_campaigns[campaignID].raised += uint256(claimableD18[0]);
        IRewardsManagerModule(synthCoreProxy).claimRewards(
            accountID,
            _poolID,
            sUSDC,
            distributors[0]
        );
        // get back user tokens (fusdc)
       
        // _withdrawFundsFromAccount(campaign.currentStake);
    }

    function _claimUserCollateral(
        uint128 campaignID,
        address user,
        uint amount
    ) internal {
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        uint userStake = s_userStakes[msg.sender][campaignID];
        require(userStake >= amount, "");
        IRewardsManagerModule(synthCoreProxy).updateRewards(
            _poolID,
            sUSDC,
            accountID
        );
        s_campaigns[campaignID].currentStake -= uint256(amount);
        _updateWithdrawContribution(msg.sender, campaignID, amount);
        _redeemFromSyntethix(accountID, amount);
    }

    
    function _redeemFromSyntethix(uint128 accountID, uint amount) internal {
        uint256 adjustedAmount =  amount * 1e12;
        ICollateralModule(synthCoreProxy).withdraw(accountID, sUSDC, adjustedAmount);
        IWrapperModule(wrapProxy).unwrap(1, adjustedAmount, 0);
    }

    function _createAerodromePoolAndAddLiquidity(
        address xToken,
        uint256 amountRaised,
        uint256 poolSupply
    ) internal returns (address poolAddress) {
        poolAddress = IPoolFactory(aerodromePoolFactory).createPool(
            xToken,
            mockLiquidityToken,
            false
        );
        IERC20_0(xToken).approve(aerodromeRouter, poolSupply);
        IERC20_0(mockLiquidityToken).approve(aerodromeRouter, amountRaised);
        IRouter(aerodromeRouter).addLiquidity(
            xToken,
            mockLiquidityToken,
            false,
            poolSupply,
            amountRaised,
            poolSupply,
            0,
            address(this),
            block.timestamp
        );
    }

    function _getUserContribution(
        uint128 campaignID,
        address user
    ) internal view returns (uint256 userContribution) {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        uint256 pastContribution = (block.timestamp - userStake.lastStakeTime) *
            userStake.amount;
        userContribution = userStake.totalContribution + pastContribution;
    }

    function _getTotalContribution(
        uint128 campaignID
    ) internal view returns (uint256 totalContribution) {
        Launch storage launch = s_launches[campaignID];
        uint256 pastContribution = (block.timestamp - launch.lastUpdateTime) *
            launch.totalStaked;
        totalContribution = launch.totalContribution + pastContribution;
    }

    function _updateAddContribution(
        address user,
        uint128 campaignID,
        uint256 amount
    ) internal {
        require(amount > 0, "Amount must be greater than zero");

        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];

        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;

        if (userStake.amount > 0) {
            uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
            userStake.totalContribution += userTimeElapsed * userStake.amount;
        }

        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked += amount;
    }

    function _updateWithdrawContribution(
        address user,
        uint128 campaignID,
        uint256 amount
    ) internal {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        require(userStake.amount >= amount, "Insufficient staked amount");

        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;

        uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
        userStake.totalContribution += userTimeElapsed * userStake.amount;

        userStake.amount -= amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked -= amount;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Return the selector to confirm the transfer
        return this.onERC721Received.selector;
    }
}
