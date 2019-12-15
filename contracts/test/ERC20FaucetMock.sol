pragma solidity ^0.5.8;

import "../ERC20Faucet.sol";
import "./TimeHelpersMock.sol";


contract ERC20FaucetMock is ERC20Faucet, TimeHelpersMock {
    constructor (ERC20[] memory _tokens, uint256[] memory _periods, uint256[] memory _amounts)
        ERC20Faucet(_tokens, _periods, _amounts)
        public
    {}
}
