// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LogoPay {
    address public _owner;

    address[] _froms;
    mapping(address => uint256) _received;

    event Received(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);

    modifier onlyOwner {
        require(msg.sender == _owner, "not owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    receive() external payable {
        _froms.push(msg.sender);
        _received[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        _froms.push(msg.sender);
        _received[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    function withdraw(address to_) external onlyOwner {
        require(to_ != address(0), "invalid target address");
        uint256 balance = getBalance();
        require(balance > 0, "insufficient balance");
        payable(to_).transfer(balance);
        emit Withdraw(to_, balance);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getReceived(address from_) public view returns (uint256) {
        return _received[from_];
    }

    function getFromNum() public view returns (uint256) {
        return _froms.length;
    }

    function getFroms(uint256 _start, uint256 _count) public view returns (address[] memory) {
        require(_froms.length > 0, "insufficient quantity");
        require(_start < _froms.length, "invalid _start, must be in [0, getFromNum())");
        require(_count > 0 && _count <= 100, "max return 100 froms");
        uint num = _count;
        if(_start + _count >= _froms.length) {
            num = _froms.length - _start;
        }
        address[] memory ret = new address[](num);
        for(uint i; i < num; i++) {
            ret[i] = _froms[i + _start];
        }
        return ret;
    }
}