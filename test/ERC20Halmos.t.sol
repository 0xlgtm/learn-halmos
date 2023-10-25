// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract HalmosToken is ERC20, Ownable {
    function name() public view override returns (string memory) {
        return "HalmosToken";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return "HT";
    }

    function initialize() public {
        _initializeOwner(msg.sender); // No _guardInitializeOwner()
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract HalmosTokenTest is SymTest, Test {
    HalmosToken token;
    // keccak256("me")
    bytes32 me = 0x7b6396a8566148c94f742592920b8b2410abd113b57f9692eb4d22626bc0481d;
    address owner = address(uint160(uint256(me)));

    function setUp() public {
        token = new HalmosToken();
        vm.startPrank(owner);
        token.initialize();
        // uint256 initialSupply = svm.createUint256("initialSupply");
        // vm.assume(initialSupply < 10);
        // token.mint(owner, initialSupply);
    }

    function check_transfer() public {
        // specify input conditions
        address sender = svm.createAddress("sender");
        address receiver = svm.createAddress("receiver");
        uint256 senderBalance = svm.createUint256("senderBalance");
        uint256 receiverBalance = svm.createUint256("receiverBalance");
        uint256 amount = svm.createUint256("amount");

        // Assumptions
        uint256 totalSupply = token.totalSupply();
        vm.assume(senderBalance + receiverBalance <= totalSupply);
        vm.assume(amount <= senderBalance);
        vm.assume(receiverBalance + amount <= totalSupply);
        
        // Call target contract
        vm.startPrank(owner);
        // token.transfer(sender, senderBalance);
        // token.transfer(receiver, receiverBalance);
        token.mint(sender, senderBalance);
        token.mint(receiver, receiverBalance);
        vm.stopPrank();
        vm.prank(sender);
        token.transfer(receiver, amount);

        // check output state
        assert(token.balanceOf(sender) == senderBalance - amount);
        assert(token.balanceOf(receiver) == receiverBalance + amount);
    }
    


    function check_transferFrom() public {
        // specify input conditions
        address sender = svm.createAddress("sender");
        address receiver = svm.createAddress("receiver");
        uint256 senderBalance = svm.createUint256("senderBalance");
        uint256 receiverAllowance = svm.createUint256("receiverAllowance");
        uint256 receiverBalance = svm.createUint256("receiverBalance");
        uint256 amount = svm.createUint256("amount");

        // Assumptions
        uint256 totalSupply = token.totalSupply();
        vm.assume(senderBalance + receiverBalance <= totalSupply);
        vm.assume(amount <= senderBalance);
        vm.assume(amount <= receiverAllowance);
        vm.assume(receiverBalance + amount <= totalSupply);
        
        // Call target contract
        vm.startPrank(owner);
        // token.transfer(sender, senderBalance);
        // token.transfer(receiver, receiverBalance);
        token.mint(sender, senderBalance);
        token.mint(receiver, receiverBalance);
        vm.stopPrank();
        vm.prank(sender);
        token.approve(receiver, receiverAllowance);
        vm.prank(receiver);
        token.transferFrom(sender, receiver, amount);

        // check output state
        assert(token.balanceOf(sender) == senderBalance - amount);
        assert(token.balanceOf(receiver) == receiverBalance + amount);
        assert(token.allowance(sender, receiver) == receiverAllowance - amount);
    }

    // This test checks that the only way for a receiver's balance
    // to increase is by decreasing the allowance.
    function check_NoBackdoor(bytes4 selector, bytes memory args, address caller, address other) public virtual {
        // consider two arbitrary distinct accounts
        vm.assume(other != caller);

        // record their current balances
        uint256 oldBalanceOther = (token).balanceOf(other);

        uint256 oldAllowance = (token).allowance(other, caller);

        // consider an arbitrary function call to the token from the caller
        vm.prank(caller);
        (bool success,) = address(token).call(abi.encodePacked(selector, args));
        vm.assume(success);

        uint256 newBalanceOther = (token).balanceOf(other);

        // ensure that the caller cannot spend other' tokens without approvals
        if (newBalanceOther < oldBalanceOther) {
            assert(oldAllowance >= oldBalanceOther - newBalanceOther);
        }
    }
}
