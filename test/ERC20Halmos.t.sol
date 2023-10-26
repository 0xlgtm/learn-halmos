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

    // If you want to test that the check_noBackdoor() test works, uncomment this
    // function and the stuff in setUp()
    // function steal(address _from) public {
    //     _transfer(_from, msg.sender, balanceOf(_from));
    // }
}

// $ halmos --storage-layout=generic
contract HalmosTokenTest is SymTest, Test {
    HalmosToken token;
    address owner;
    address caller;
    address other;

    function setUp() public {
        // Specify input conditions
        owner = svm.createAddress("owner");
        caller = svm.createAddress("caller");
        // other = 0x1234567890123456789012345678901234567899;
        other = svm.createAddress("other");

        uint256 callerBalance = svm.createUint256("callerBalance");
        uint256 otherBalance = svm.createUint256("otherBalance");
        uint256 callerAllowance = svm.createUint256("callerAllowance");

        // Assumptions
        vm.assume(owner != caller && owner != other && caller != other);
        vm.assume(callerBalance > 0 && otherBalance > 0);
        vm.assume(callerBalance + otherBalance <= type(uint256).max);

        // Set up initial state
        vm.startPrank(owner);
        token = new HalmosToken();
        token.initialize();
        token.mint(caller, callerBalance);
        token.mint(other, otherBalance);
        vm.stopPrank();

        vm.prank(other);
        token.approve(caller, callerAllowance);
    }

    function check_transfer() public {
        // Specify input conditions
        uint256 amount = svm.createUint256("amount");
        uint256 callerBalanceBefore = token.balanceOf(caller);
        uint256 otherBalanceBefore = token.balanceOf(other);

        // Assumptions
        vm.assume(amount <= token.balanceOf(caller));

        // Call target contract
        vm.prank(caller);
        token.transfer(other, amount);

        // Check output state
        uint256 callerBalanceAfter = token.balanceOf(caller);
        uint256 otherBalanceAfter = token.balanceOf(other);
        assertEq(callerBalanceAfter, callerBalanceBefore - amount);
        assertEq(otherBalanceAfter, otherBalanceBefore + amount);
        assertEq(callerBalanceAfter + otherBalanceAfter, token.totalSupply()); // Checks that total supply doesn't magically increase.
    }

    function check_transferFrom() public {
        // Specify input conditions
        uint256 amount = svm.createUint256("amount");
        uint256 callerBalanceBefore = token.balanceOf(caller);
        uint256 callerAllowanceBefore = token.allowance(other, caller);
        uint256 otherBalanceBefore = token.balanceOf(other);

        // Assumptions
        vm.assume(amount <= token.balanceOf(other));

        // Call target contract
        vm.prank(caller);
        token.transferFrom(other, caller, amount);

        // Check output state
        uint256 callerBalanceAfter = token.balanceOf(caller);
        uint256 otherBalanceAfter = token.balanceOf(other);
        assertEq(callerBalanceAfter, callerBalanceBefore + amount);
        assertEq(otherBalanceAfter, otherBalanceBefore - amount);
        assertEq(callerBalanceAfter + otherBalanceAfter, token.totalSupply()); // Checks that total supply doesn't magically increase.
        assertGe(callerAllowanceBefore, otherBalanceBefore - otherBalanceAfter);
    }

    // Note regarding args
    // Bigger is better but it makes the algorithm slower since there are more combinations.
    // Excess data in calldata will be ignored. If calldata is too short, all 0s will be used.
    // e.g. if you use svm.createBytes(less than 20, 'data'), this function can never fail because address is at least 20 bytes.
    // I guess ideally use the size of the longest possible calldata.

    function check_NoBackdoor(bytes4 selector) public virtual {
        // Specify input conditions

        bytes memory args = svm.createBytes(64, 'data'); 
        uint256 callerAllowanceBefore = token.allowance(other, caller);
        uint256 otherBalanceBefore = token.balanceOf(other);

        // Call target contract
        vm.prank(caller);
        (bool success,) = address(token).call(abi.encodePacked(selector, args));
        vm.assume(success);

        // Check output state
        uint256 callerAllowanceAfter = token.allowance(other, caller);
        uint256 otherBalanceAfter = token.balanceOf(other);

        // The only way someone's balance can decrease is through transferFrom.
        if (otherBalanceAfter < otherBalanceBefore) {
            assertEq(callerAllowanceBefore, callerAllowanceAfter + (otherBalanceBefore - otherBalanceAfter));
        }
    }
}
