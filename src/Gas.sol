// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract GasContract {
    uint256 public totalSupply;
    address public contractOwner;
    uint8 private constant TRADE_PERCENT = 12;
    
    mapping(address => uint256) public balances;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    
    uint256 public paymentCounter;
    
   
    uint8 public tradeFlag = 1;
    uint8 public basicFlag = 0;
    uint8 public dividendFlag = 1;
    
    mapping(address => uint256) public isOddWhitelistUser;
    uint256 public wasLastOdd = 1;
    
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    
    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; 
        address recipient;
        address admin;
        uint256 amount;
    }
    
    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    
   
    struct ImportantStruct {
        uint256 amount;
        uint256 valueA; 
        uint256 bigValue;
        uint256 valueB;
        bool paymentStatus;
        address sender;
    }
    
    mapping(address => ImportantStruct) public whiteListStruct;
    
    History[] public paymentHistory;
    
    event AddedToWhitelist(address userAddress, uint256 tier);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(address admin, uint256 ID, uint256 amount, string recipient);
    event WhiteListTransfer(address indexed recipient);
    event supplyChanged(address indexed, uint256 indexed);
    
    modifier onlyAdminOrOwner() {
        require(
            checkForAdmin(msg.sender) || msg.sender == contractOwner,
            "Only admin or owner"
        );
        _;
    }
    
    modifier checkIfWhiteListed(address sender) {
        require(msg.sender == sender, "Sender mismatch");
        uint256 usersTier = whitelist[msg.sender];
        require(usersTier > 0, "Not whitelisted");
        require(usersTier <= 3, "Invalid tier");
        _;
    }
    
    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        
   
        uint256 adminCount = _admins.length < 5 ? _admins.length : 5;
        for (uint256 i = 0; i < administrators.length; i++) {
            if (i < adminCount && _admins[i] != address(0)) {
                administrators[i] = _admins[i];
                
                if (_admins[i] == contractOwner) {
                    balances[contractOwner] = totalSupply;
                    emit supplyChanged(_admins[i], totalSupply);
                } else {
                    balances[_admins[i]] = 0;
                    emit supplyChanged(_admins[i], 0);
                }
            }
        }
    }
    
    function checkForAdmin(address _user) public view returns (bool) {
        for (uint256 i = 0; i < administrators.length; i++) {
            if (administrators[i] == _user) {
                return true;
            }
        }
        return false;
    }
    
    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }
    
    function getTradingMode() public view returns (bool) {
        return (tradeFlag == 1 || dividendFlag == 1);
    }
    
    function addHistory(address _updateAddress, bool _tradeMode) public returns (bool, bool) {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        
        return (true, _tradeMode);
    }
    
    function getPaymentHistory() public view returns (History[] memory) {
        return paymentHistory;
    }
    
    function getPayments(address _user) public view returns (Payment[] memory) {
        require(_user != address(0), "Invalid address");
        return payments[_user];
    }
    
    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool) {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(bytes(_name).length <= 8, "Name too long");
        
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        
        emit Transfer(_recipient, _amount);
        
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        
        return true;
    }
    
    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(_ID > 0, "Invalid ID");
        require(_amount > 0, "Invalid amount");
        require(_user != address(0), "Invalid address");
        
        for (uint256 i = 0; i < payments[_user].length; i++) {
            if (payments[_user][i].paymentID == _ID) {
                payments[_user][i].adminUpdated = true;
                payments[_user][i].admin = msg.sender;
                payments[_user][i].paymentType = _type;
                payments[_user][i].amount = _amount;
                
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][i].recipientName
                );
                
                break;
            }
        }
    }
    
    function addToWhitelist(address _userAddrs, uint256 _tier) public onlyAdminOrOwner {
        require(_tier < 255, "Tier too high");
        
      
        whitelist[_userAddrs] = _tier;
        
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }
        
      
        if (wasLastOdd == 1) {
            wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = 1;
        } else {
            wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = 0;
        }
        
        emit AddedToWhitelist(_userAddrs, _tier);
    }
    
    function whiteTransfer(address _recipient, uint256 _amount) public checkIfWhiteListed(msg.sender) {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_amount > 3, "Amount too small");
        
       
        whiteListStruct[msg.sender] = ImportantStruct({
            amount: _amount,
            valueA: 0,
            bigValue: 0,
            valueB: 0,
            paymentStatus: true,
            sender: msg.sender
        });
        
        uint256 tierBonus = whitelist[msg.sender];
        
        balances[msg.sender] = balances[msg.sender] - _amount + tierBonus;
        balances[_recipient] = balances[_recipient] + _amount - tierBonus;
        
        emit WhiteListTransfer(_recipient);
    }
    
    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }
    
    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }
    
    fallback() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}