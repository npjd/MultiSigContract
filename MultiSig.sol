// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSig {
    // Contract Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );

    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    // Wallet Owners
    address[] public owners;
    // Mapping to check for unique owners
    mapping(address => bool) public isOwner;
    // Number of confirmations required for each transaction
    uint256 public numConfirmations;
    // Public name of wallet
    string public name;

    // Transaction Struct

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        uint256 txIndex;
        string descriptionHash;
        uint256 timestampSubmitted;
        uint256 timestampExecuted;
    }

    // Mapping for a transactions confirmations based on the transaction index

    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Current transactions
    Transaction[] public transactions;

    constructor(
        address[] memory _owners,
        uint256 _numConfirmationsRequired,
        string memory _name
    ) {
        require(_owners.length > 0, "owners required");
        require(keccak256(abi.encodePacked(_name)) != "", "name required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "numConfirmationsRequired must be greater than 0 and less than or equal to the number of owners"
        );

        // Check to see if owners are unique
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmations = _numConfirmationsRequired;
        name = _name;
    }

    // Emit event when money gets deposited into the wallet
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // for remix testing
    function deposit() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactions() external view returns (Transaction[] memory) {
        return transactions;
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        string memory _descriptionHash
    ) public onlyOwner {
        uint256 _txIndex = transactions.length;

        // when submitting a contract, make the owner submitting the transaction confirm it too
        Transaction memory _tx = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 1,
            txIndex: _txIndex,
            descriptionHash: _descriptionHash,
            timestampSubmitted: block.timestamp,
            timestampExecuted: 0
        });

        transactions.push(_tx);

        isConfirmed[_txIndex][msg.sender] = true;

        emit SubmitTransaction(msg.sender, _txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        // Increment transaction counter
        transaction.numConfirmations += 1;
        // Set mapping
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        // check if transaction has enough confirmations
        require(
            transaction.numConfirmations >= numConfirmations,
            "not enough confirmations"
        );

        transaction.executed = true;
        transaction.timestampExecuted = block.timestamp;
        // execute transaction
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        // make sure transaction goes through
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        // Make sure owner confirmed transaction already
        require(
            isConfirmed[_txIndex][msg.sender],
            "You have not confirmed the transaction yet"
        );
        isConfirmed[_txIndex][msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not a valid owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "Transactiona already executed"
        );
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }
}
