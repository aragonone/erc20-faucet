pragma solidity ^0.5.8;


contract Ownable {
    string private constant ERROR_SENDER_NOT_OWNER = "OWNABLE_SENDER_NOT_OWNER";
    string private constant ERROR_NEW_OWNER_ADDRESS_ZERO = "OWNABLE_NEW_OWNER_ADDRESS_ZERO";

    address private owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, ERROR_SENDER_NOT_OWNER);
        _;
    }

    constructor () public {
        _setOwner(msg.sender);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), ERROR_NEW_OWNER_ADDRESS_ZERO);
        _setOwner(_newOwner);
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function _setOwner(address _newOwner) private {
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
