pragma solidity ^0.5.8;

import "./Ownable.sol";
import "./os/ERC20.sol";
import "./os/SafeMath.sol";
import "./os/SafeERC20.sol";
import "./os/TimeHelpers.sol";


contract ERC20Faucet is Ownable, TimeHelpers {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    string private constant ERROR_QUOTA_AMOUNT_ZERO = "FAUCET_QUOTA_AMOUNT_ZERO";
    string private constant ERROR_QUOTA_PERIOD_ZERO = "FAUCET_QUOTA_PERIOD_ZERO";
    string private constant ERROR_TRANSFER_FAILED = "FAUCET_TRANSFER_FAILED";
    string private constant ERROR_NOT_ENOUGH_SUPPLY = "FAUCET_NOT_ENOUGH_SUPPLY";
    string private constant ERROR_FUTURE_START_DATE = "FAUCET_FUTURE_START_DATE";
    string private constant ERROR_FUTURE_LAST_PERIOD = "FAUCET_FUTURE_LAST_PERIOD";
    string private constant ERROR_AMOUNT_EXCEEDS_QUOTA = "FAUCET_AMOUNT_EXCEEDS_QUOTA";
    string private constant ERROR_INVALID_QUOTAS_LENGTH = "FAUCET_INVALID_QUOTAS_LENGTH";

    struct Quota {
        uint256 period;
        uint256 amount;
    }

    struct Withdrawal {
        uint256 lastPeriodId;
        mapping (address => uint256) lastPeriodAmount;
    }

    uint256 private startDate;
    mapping (address => Quota) private tokenQuotas;
    mapping (address => uint256) private supplyByToken;
    mapping (address => Withdrawal) private withdrawals;

    event TokenQuotaSet(ERC20 indexed token, uint256 period, uint256 amount);
    event TokensDonated(ERC20 indexed token, address indexed donor, uint256 amount, uint256 totalSupply);
    event TokensWithdrawn(ERC20 indexed token, address indexed account, uint256 amount, uint256 totalSupply);

    /**
    * @notice Initialize faucet
    * @param _tokens List of ERC20 tokens to be set
    * @param _periods List of periods length for each ERC20 token quota
    * @param _amounts List of quota amounts for each ERC20 token
    */
    constructor (ERC20[] memory _tokens, uint256[] memory _periods, uint256[] memory _amounts) Ownable() public {
        startDate = getTimestamp();
        _setQuotas(_tokens, _periods, _amounts);
    }

    /**
    * @notice Donate `@tokenAmount(_token, _amount)`
    * @param _token ERC20 token being deposited
    * @param _token Amount being deposited
    */
    function donate(ERC20 _token, uint256 _amount) external {
        address tokenAddress = address(_token);
        require(tokenQuotas[tokenAddress].amount > 0, ERROR_QUOTA_AMOUNT_ZERO);

        uint256 totalSupply = supplyByToken[tokenAddress].add(_amount);
        supplyByToken[tokenAddress] = totalSupply;

        emit TokensDonated(_token, msg.sender, _amount, totalSupply);
        require(_token.safeTransferFrom(msg.sender, address(this), _amount), ERROR_TRANSFER_FAILED);
    }

    /**
    * @notice Withdraw `@tokenAmount(_token, _amount)`
    * @param _token ERC20 token being withdrawn
    * @param _token Amount being withdrawn
    */
    function withdraw(ERC20 _token, uint256 _amount) external {
        // Check there are enough tokens
        address tokenAddress = address(_token);
        uint256 totalSupply = supplyByToken[tokenAddress];
        require(totalSupply >= _amount, ERROR_NOT_ENOUGH_SUPPLY);

        // If the last period is in the future, something went wrong somewhere
        Withdrawal storage withdrawal = withdrawals[msg.sender];
        uint256 lastPeriodId = withdrawal.lastPeriodId;
        Quota storage quota = tokenQuotas[tokenAddress];
        uint256 currentPeriodId = _getCurrentPeriodId(quota);
        require(lastPeriodId <= currentPeriodId, ERROR_FUTURE_LAST_PERIOD);

        // Check withdrawal amount does not exceed period quota based on current period
        uint256 lastPeriodAmount = withdrawal.lastPeriodAmount[tokenAddress];
        uint256 newPeriodAmount = (lastPeriodId == currentPeriodId) ? lastPeriodAmount.add(_amount) : _amount;
        require(newPeriodAmount <= quota.amount, ERROR_AMOUNT_EXCEEDS_QUOTA);

        // Update withdrawal and transfer tokens
        uint256 newTotalSupply = totalSupply.sub(_amount);
        supplyByToken[tokenAddress] = newTotalSupply;
        withdrawal.lastPeriodId = currentPeriodId;
        withdrawal.lastPeriodAmount[tokenAddress] = newPeriodAmount;

        // Transfer tokens
        emit TokensWithdrawn(_token, msg.sender, _amount, newTotalSupply);
        require(_token.safeTransfer(msg.sender, _amount), ERROR_TRANSFER_FAILED);
    }

    /**
    * @notice Set a list of token quotas
    * @param _tokens List of ERC20 tokens to be set
    * @param _periods List of periods length for each ERC20 token quota
    * @param _amounts List of quota amounts for each ERC20 token
    */
    function setQuotas(ERC20[] calldata _tokens, uint256[] calldata _periods, uint256[] calldata _amounts) external onlyOwner {
        _setQuotas(_tokens, _periods, _amounts);
    }

    /**
    * @dev Tell the start date of the faucet
    * @return Start date of the faucet
    */
    function getStartDate() external view returns (uint256) {
        return startDate;
    }

    /**
    * @dev Tell the quota information for a certain token
    * @param _token ERC20 token being queried
    * @return period Periods length for the requested ERC20 token quota
    * @return amount Quota amount for the requested ERC20 token
    */
    function getQuota(ERC20 _token) external view returns (uint256 period, uint256 amount) {
        Quota storage quota = tokenQuotas[address(_token)];
        return (quota.period, quota.amount);
    }

    /**
    * @dev Tell the total supply of the faucet for a certain ERC20 token
    * @param _token ERC20 token being queried
    * @return Total supply of the faucet for the requested ERC20 token
    */
    function getTotalSupply(ERC20 _token) external view returns (uint256) {
        return supplyByToken[address(_token)];
    }

    /**
    * @dev Tell the last period withdrawals of an ERC20 token for a certain account
    * @param _account Address of the account being queried
    * @param _token ERC20 token being queried
    * @return id ID of the last period when the requested account withdraw a certain amount
    * @return amount Amount withdrawn by the requested account during the last period
    */
    function getWithdrawal(address _account, ERC20 _token) external view returns (uint256 id, uint256 amount) {
        Withdrawal storage withdrawal = withdrawals[_account];
        uint256 lastPeriodAmount = withdrawal.lastPeriodAmount[address(_token)];
        return (withdrawal.lastPeriodId, lastPeriodAmount);
    }

    /**
    * @dev Internal function to set a list of token quotas
    * @param _tokens List of ERC20 tokens to be set
    * @param _periods List of periods length for each ERC20 token quota
    * @param _amounts List of quota amounts for each ERC20 token
    */
    function _setQuotas(ERC20[] memory _tokens, uint256[] memory _periods, uint256[] memory _amounts) internal {
        require(_tokens.length == _periods.length, ERROR_INVALID_QUOTAS_LENGTH);
        require(_tokens.length == _amounts.length, ERROR_INVALID_QUOTAS_LENGTH);

        for (uint256 i = 0; i < _tokens.length; i++) {
            _setQuota(_tokens[i], _periods[i], _amounts[i]);
        }
    }

    /**
    * @dev Internal function to set a token quota
    * @param _token ERC20 token to be set
    * @param _period Periods length for the ERC20 token quota
    * @param _amount Quota amount for the ERC20 token
    */
    function _setQuota(ERC20 _token, uint256 _period, uint256 _amount) internal {
        require(_period > 0, ERROR_QUOTA_PERIOD_ZERO);
        require(_amount > 0, ERROR_QUOTA_AMOUNT_ZERO);

        Quota storage quota = tokenQuotas[address(_token)];
        quota.period = _period;
        quota.amount = _amount;
        emit TokenQuotaSet(_token, _period, _amount);
    }

    /**
    * @dev Internal function to get the current period ID of a certain token quota
    * @param _quota ERC20 token quota being queried
    * @return ID of the current period for the given token quota based on the current timestamp
    */
    function _getCurrentPeriodId(Quota storage _quota) internal view returns (uint256) {
        // Check the faucet has already started
        uint256 startTimestamp = startDate;
        uint256 currentTimestamp = getTimestamp();
        require(currentTimestamp >= startTimestamp, ERROR_FUTURE_START_DATE);

        // No need for SafeMath: we already checked current timestamp is greater than or equal to start date
        uint256 timeDiff = currentTimestamp - startTimestamp;
        uint256 currentPeriodId = timeDiff / _quota.period;
        return currentPeriodId;
    }
}
