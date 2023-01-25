//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

//An ICO-cum-coin sale contract
// During ICO invest() will be called for ico investors.
// After ico ends, invest() will revert. Buy() fuction will be called by users to by coins.
// The following values can not be changed after deployment: admin, tokenPrice, saleEnd, tokenTradeStart, minInvestment.

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SalvaICO {
    using SafeERC20 for IERC20;
    IERC20 public salvaContract;

    bool private init;

    //Enums.

    enum State {
        beforeStart,
        running,
        ended,
        halted
    }

    enum ContractState {
        halted,
        unhalted
    }

    // State vars.

    State public state;
    ContractState public contractState;

    // Admin can be changed by the current admin.
    address public admin;

    // Following values are not modifiable after deployment.
    uint256 public tokenPrice = 1 ether; // 1 MATIC = 1 Coin.
    uint256 public raisedAmount; // Value will be in wei
    // uint256 public saleStart = block.timestamp;
    uint256 public saleEnd = block.timestamp + 2678400; //31 days

    uint256 public tokenTradeStart = saleEnd + 604800; //A week after saleEnd. 7 days = 604800
    uint256 public minInvestment = 1 ether;

    // Non modifialble values ends here.

    mapping(address => bool) private blocked;

    // Events
    event Invested(
        address indexed investor,
        uint256 indexed maticReceived,
        uint256 tokensSent
    );
    event CoinSold(address indexed buyer, uint256 indexed amount);
    event AdminChanged(address indexed newAdmin, address indexed oldAdmin);
    event SalvaTokensWithdrawn(
        address indexed withdrawer,
        IERC20 tokenAddress,
        uint256 indexed amount
    );
    event ERC20TokenWithdrawal(
        address withdrawer,
        address ERC20token,
        uint256 amount
    );

    event ERC20Withdrawn(address receiver, uint256 value);

    // Setting salvacontract address and amin in constructor

    constructor(address _salvaContract) {
        require(Address.isContract(_salvaContract), "ICO: invalid contract.");
        salvaContract = IERC20(_salvaContract);
        admin = msg.sender;
        state == State.beforeStart;
    }

    // Admin callable function to change dividend coin address

    function changeCoinAddress(IERC20 _coinContract) external returns (bool) {
        require(msg.sender == admin, "ICO: only admin.");

        require(init == false, "ICO: init must be  fals");

        salvaContract = _coinContract;

        init = true;
        return true;
    }

    /// @dev function to stop ico.

    function stop() external {
        require(
            contractState == ContractState.unhalted,
            "ICO: contract halted."
        );

        require(msg.sender == admin, "ICO: only admin!");
        require(state != State.halted, "ICO: already stopped!");
        state = State.halted;
    }

    /// @dev function to start ico callable only by the admin

    function start() external {
        require(
            contractState == ContractState.unhalted,
            "ICO: contract halted."
        );

        require(msg.sender == admin, "ICO: only admin!");
        require(state == State.halted, "ICO: already running!");
        state = State.running;
    }

    /// @dev Public function too get current state of ICO.

    function getICOState() public view returns (State) {
        if (block.timestamp <= saleEnd || state == State.running) {
            return State.running;
        } else if (block.timestamp > saleEnd) {
            return State.ended;
        } else if (state == State.halted) {
            return State.halted;
        } else if (state == State.beforeStart) {
            return State.beforeStart;
        } else {
            return state;
        }
    }

    // function called when sending eth to the contract.
    // this function can not be called and revertes after ico ends. Third line of the below code ensures this.

    function invest() external payable returns (bool) {
        require(
            contractState == ContractState.unhalted,
            "ICO: contract halted."
        );

        require(!blocked[msg.sender], "ICO: user blocked.");

        state = getICOState();
        require(state == State.running, "ICO: must be in running state.");

        // after ico ends. this function reverts here.
        require(block.timestamp < saleEnd, "ICO: ico ended.");
        require(msg.value >= minInvestment, "ICO: amount must be >= 1 MATIC.");

        require(
            salvaContract.balanceOf(address(this)) > 0,
            "ICO: 0 contract fund"
        );

        raisedAmount += msg.value;

        // require(raisedAmount <= hardCap);

        uint256 _valueSent = msg.value;

        uint256 _salvaCoins = (_valueSent * 10**18) / tokenPrice;

        address _to = msg.sender;

        emit Invested(_to, msg.value, _salvaCoins);

        // sending Salvacoin to buyer

        _sendTokens(_to, _salvaCoins);

        return true;
    }

    // function to receive ether

    receive() external payable {}

    /// @dev Private function for sending tokens

    function _sendTokens(address _to, uint256 _salvaCoins) private {
        salvaContract.safeTransfer(_to, _salvaCoins);
    }

    /// @dev Admin function to withdraw unsold ERC20 tokens
    /// @dev Total remaining ERC20 token is sent back to the caller(admin)
    /// @dev Can be called only after ico sale ends. 2nd line of this function ensures that.

    function withdrawSalvaTokens() external returns (bool success) {
        require(
            contractState == ContractState.unhalted,
            "ICO: in halted state."
        );

        require(msg.sender == admin, "ICO: only admin!");
        require(block.timestamp > saleEnd); // the token will be transferable only after tokenTradeStart
        address _to = msg.sender;
        uint256 _amount = this.contractTokenBalance();

        if (_amount == 0) {
            revert("ICO: zero coins to withdraw.");
        }

        emit SalvaTokensWithdrawn(_to, salvaContract, _amount);

        _sendTokens(_to, _amount);

        return true;
    }

    /// @dev Admin function to recover other ERC20 tokens than SalvaCoin.

    function recoverOtherTokens(address _tokenAddress, uint256 _tokenAmount)
        public
    {
        require(
            contractState == ContractState.unhalted,
            "ICO: in halted state."
        );

        address _caller = msg.sender;
        require(_caller == admin, "ICO: only admin!");

        require(
            _tokenAddress != address(this),
            "ICO: cannot be this contract address"
        );

        uint256 _tokenBalance = IERC20(_tokenAddress).balanceOf(address(this));

        require(_tokenAmount >= _tokenBalance, "ICO: insufficient balance");

        emit ERC20Withdrawn(msg.sender, _tokenBalance);

        emit ERC20TokenWithdrawal(_caller, _tokenAddress, _tokenBalance);

        IERC20(_tokenAddress).transfer(_caller, _tokenAmount);
    }

    /// @dev Admin function to withdraw total ico sales amount in MATIC to admin wallet.
    /// @dev Total ico amount is sent to the caller(admin).

    function withdrawICOAmount() external {
        require(
            contractState == ContractState.unhalted,
            "ICO: in halted state."
        );

        require(msg.sender == admin, "ICO: only admin!");

        uint256 _amount = address(this).balance;

        require(_amount > 0, "ICO: zero ICO contract balance.");

        address payable _to = payable(msg.sender);

        (bool success, ) = _to.call{value: _amount}("");

        require(success, "ICO: ICO amount withdrawal failed");
    }

    /// @dev View function for fetching salva token balance of this contract.

    function contractTokenBalance() external view returns (uint256 _tokens) {
        require(msg.sender == admin, "ICO: only admin!");
        address _thisContract = address(this);
        return salvaContract.balanceOf(_thisContract);
    }

    /// @dev Only admin can block users.

    function blockUser(address _user) external returns (bool) {
        require(
            contractState == ContractState.unhalted,
            "ICO: in halted state."
        );

        require(msg.sender == admin, "ICO: only admin!");

        if (blocked[_user]) {
            revert("ICO: alreday blocked.");
        } else {
            blocked[_user] = true;
        }
        return true;
    }

    /// @dev Only admin can unblock users.

    function unBlockUser(address _user) external returns (bool) {
        require(
            contractState == ContractState.unhalted,
            "ICO: in halted state."
        );

        require(msg.sender == admin, "ICO: only admin!");

        if (!blocked[_user]) {
            revert("ICO: already unblocked.");
        } else {
            blocked[_user] = false;
        }
        return true;
    }

    /// @dev Admin can change the contract state from halted to unHalted and back to halted.
    /// @dev In in halted mode. All sate modifying function are going to revert.

    function changeContractState() external {
        require(msg.sender == admin, "ICO: only admin!");

        if (contractState == ContractState.unhalted) {
            contractState = ContractState.halted;
        } else {
            contractState = ContractState.unhalted;
        }
    }

    /// @dev Buy function to buy SalvaCoin send to this contract by SalvaContract.
    /// @dev Only callable after ICO ends.

    function buyCoin() external payable returns (bool) {
        require(block.timestamp > saleEnd, "ICO: only after ICO ends.");
        require(msg.value >= tokenPrice, "ICO: send right amount.");
        address _to = msg.sender;
        uint256 _salvaCoins = (msg.value * 10**18) / tokenPrice;

        //emitting event.
        emit CoinSold(_to, _salvaCoins);
        salvaContract.safeTransfer(_to, _salvaCoins);
        return true;
    }

    /// @dev Admin can change the admin of this contract

    function changeAdmin(address _newAdmin) external returns (bool) {
        address _caller = msg.sender;
        require(_caller == admin, "ICO: only admin.");

        admin = _newAdmin;

        // emitting event.
        emit AdminChanged(_newAdmin, admin);

        return true;
    }

    // MUST REMOVE THIS FUNCTION BEFORE MAINNET DEPLOYMENT

    // function changeSalvaCoinAddress(IERC20 _coinAddress) external {
    //     salvaContract = _coinAddress;
    // }
}
