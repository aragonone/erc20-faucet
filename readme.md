# ERC20 Token Faucet <img align="right" src="https://raw.githubusercontent.com/aragon/design/master/readme-logo.png" height="80px" /> [![Travis branch](https://img.shields.io/travis/aragon/erc20-faucet/development.svg?style=for-the-badge)](https://travis-ci.com/aragon/erc20-faucet)

ERC20 token faucet contract that can be managed to fund accounts based on a periodic quota.

### 1. Set quotas

```solidity
  /**
  * @notice Set a list of token quotas
  * @param _tokens List of ERC20 tokens to be set
  * @param _periods List of periods length for each ERC20 token quota
  * @param _amounts List of quota amounts for each ERC20 token
  */
  function setQuotas(ERC20[] calldata _tokens, uint256[] calldata _periods, uint256[] calldata _amounts) external onlyOwner;
```

### 2. Donate

```solidity
  /**
  * @notice Donate `@tokenAmount(_token, _amount)`
  * @param _token ERC20 token being deposited
  * @param _token Amount being deposited
  */
  function donate(ERC20 _token, uint256 _amount) external;
```

### 3. Withdraw

```solidity
  /**
  * @notice Withdraw `@tokenAmount(_token, _amount)`
  * @param _token ERC20 token being withdrawn
  * @param _token Amount being withdrawn
  */
  function withdraw(ERC20 _token, uint256 _amount) external;
```
