// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface token {
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function totalSupply() external view returns (uint);
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }

    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }

    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
    
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract lending is Owned{
    using SafeMath for uint;
    
    address busd;
    address matata;
    uint borrowAmount;
    uint liquidateTime;
    uint public loaningRate;
    uint inputAmount;
    uint public loaningFee;
    uint public interestRate;
    uint public paybackFee;
    uint paybackAmount;
    uint outputAmount;
    mapping(address => bool) public debtor;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public isLiquidated;
    mapping(address => uint) public borrowedAmount;
    mapping(address => uint) public borrowTime;
    mapping(address => uint) private lastClock;

    bool public active;
    

    constructor(
        address _proofToken,
        address _busd,
        uint _interestRate,
        uint _loaningFee,
        uint _paybackFee,
        uint _loaningRate,
        bool _active

    ) {

        matata = _proofToken;
        busd = _busd;
        interestRate = _interestRate;
        loaningFee = _loaningFee;
        loaningRate = _loaningRate;
        paybackFee = _paybackFee;
        active = _active;
    }
    function borrow(uint _amount) public { // Enter amount in BUSD to borrow
    require(debtor[msg.sender] == false, "You owe a debt. Please pay to borrow");
    require(active == true, "contract not active");
    if (whitelist[msg.sender] == false){
        borrowAmount = _amount.sub(loaningFee);
    } else {
        borrowAmount = _amount;
        }
    inputAmount = borrowAmount.mul(loaningRate);
    require(token(matata).transferFrom(msg.sender, address(this), inputAmount), "You need to have more MATATA to borrow the amount");
    require(token(busd).transfer(msg.sender, borrowAmount), "the contract does not have enough BUSD to lend"); 
    debtor[msg.sender] = true;
    uint remainder = ((block.timestamp).sub(lastClock[msg.sender])).mod(86400);
    lastClock[msg.sender] = (block.timestamp).sub(remainder);
    borrowTime[msg.sender] = (block.timestamp);
    borrowedAmount[msg.sender] += _amount;

    }
    function payback () public {
        uint256 _amount;
        require (debtor[msg.sender] == true, "You must owe to payback");
        _amount = borrowedAmount[msg.sender];
        require (isUserLiquidated(msg.sender) == false, "Loan is liquidated");
        outputAmount = _amount/loaningRate;
         if (whitelist[msg.sender] == false){
       paybackAmount = _amount.sub(paybackFee).sub(calculateInterest(msg.sender));
        } else {
        paybackAmount = _amount.sub(calculateInterest(msg.sender));
        }
        require(token(busd).transferFrom(msg.sender, address(this), paybackAmount), "You need to have more BUSD to PAYBACK the amount");
        require(token(matata).transfer(msg.sender, outputAmount), "the contract does not have enough MATATA"); 
        debtor[msg.sender] = false;
        borrowedAmount[msg.sender] = 0;
    }
    function calculateInterest(address _address) public view returns(uint) {
        uint activeDays = (block.timestamp.sub(lastClock[_address])).div(86400);
        if (whitelist[msg.sender] == false){
        return ((borrowedAmount[msg.sender]).mul(interestRate).mul(activeDays)).div(10000);
        } else {
            return 0;
        }
    }
     function isUserLiquidated(address _address) public view returns(bool) {
        if ((block.timestamp) - borrowTime[_address] > liquidateTime) {
            return true;
        } else {
            return false;
        }
    }

    function getBorrowedAmount(address _address) public view returns(uint){
        return (borrowedAmount[_address]);
    }
     function setLiquidateTime (uint _time) public  onlyOwner {
        liquidateTime = _time;
    }
    function setLoaningRate(uint _newLoaningRate) public onlyOwner {
    loaningRate = _newLoaningRate;
    }
    function setloaningFee (uint _newloaningFee) public onlyOwner {
        loaningFee = _newloaningFee;
    }
    function withdrawBusd (uint256 _busdAmount , address _address) onlyOwner public {
        require(token(busd).transfer(_address, _busdAmount), "insufficient BUSD balance in contract");
    }
    function withdrawMSP(uint256 _MspAmount , address _address) onlyOwner public{
        token(matata).transfer(_address , _MspAmount);
    }
    function setpaybackFee (uint _newpaybackFee) public onlyOwner {
        paybackFee = _newpaybackFee;
    }
    function setStatus (bool _newStatus) public onlyOwner {
        active = _newStatus;
    }
}
