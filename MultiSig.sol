// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


contract MultiSigWallet{

    event Deposit(address indexed sender, uint amount, uint balance);

    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);

    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address=> bool) public isOwner;
    uint public numConfirmations;

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    mapping(uint => mapping(address => bool)) public isConfirmed;


    Transaction[] public transactions;

    constructor(address[] memory _owners, uint _numConfirmationsRequired)  {
        require(_owners.length>0,"owners required");
        require(_numConfirmationsRequired >0 && _numConfirmationsRequired<= _owners.length);

        for (uint i = 0; i <_owners.length; i++){
            address owner =_owners[i];
            require(owner != address(0),"Invalid owner");
            require(!isOwner[owner],"owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmations = _numConfirmationsRequired;

    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value,address(this).balance);
    }

    // for remix testing
    function deposit() payable external {
        emit Deposit(msg.sender, msg.value,address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner{
        uint txIndex = transactions.length;
        
        transactions.push(Transaction({
            to:_to,
            value:_value,
            data:_data,
            executed:false,
            numConfirmations:0
        }));

        emit SubmitTransaction(msg.sender,txIndex,_to,_value,_data);


    }

    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations +=1;
        isConfirmed[_txIndex][msg.sender]= true;
        

        emit ConfirmTransaction(msg.sender,_txIndex);
        
    }

    function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex){

        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numConfirmations >= numConfirmations,"not enough confirmations");

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);

    }
 
    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex){
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender],"You have not confirmed the transaction yet");
        isConfirmed[_txIndex][msg.sender] = false;
        transaction.numConfirmations -=1;

        emit RevokeConfirmation(msg.sender, _txIndex);

    }

    modifier onlyOwner() {
        require(isOwner[msg.sender],"not a valid owner");
        _;
    }

    modifier txExists(uint _txIndex){
        require(_txIndex<transactions.length,"tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex){
        require(!transactions[_txIndex].executed,"Transactiona already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex){
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }


}
