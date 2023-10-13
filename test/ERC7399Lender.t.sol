// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ERC7399Lender } from "../src/ERC7399Lender.sol";
import { FlashBorrower } from "./stub/FlashBorrower.sol";
import { ERC20Mock } from "./stub/ERC20Mock.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract ERC7399LenderTest is PRBTest, StdCheats {
    ERC7399Lender internal lender;
    FlashBorrower internal borrower;
    address internal asset;
    address internal otherAsset;
    uint256 reserves = 999e18;
    uint256 fee = 10;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.

        asset = address(new ERC20Mock("Asset", "AST"));
        lender = new ERC7399Lender(IERC20(address(asset)), fee);
        borrower = new FlashBorrower(lender);

        IERC20(asset).transfer(address(lender), reserves); // Keeping 1e18 for the flash fee.
        lender.sync();
    }

    /// @dev Simple flash loan test.
    function test_flash() external {
        console2.log("test_flash");
        uint256 lenderBalance = IERC20(asset).balanceOf(address(lender));
        uint256 loan = 1e18;
        uint256 flashFee = lender.flashFee(asset, loan);
        IERC20(asset).transfer(address(borrower), flashFee);
        borrower.flashBorrow(asset, loan);

        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(asset));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + flashFee); // The amount we transferred to pay for fees, plus the
            // amount we
            // borrowed
        assertEq(borrower.flashFee(), flashFee);
        assertEq(IERC20(asset).balanceOf(address(lender)), lenderBalance + flashFee);
    }

    function test_flashAndReenter() external {
        console2.log("test_flashAndReenter");
        uint256 lenderBalance = IERC20(asset).balanceOf(address(lender));
        uint256 firstLoan = 1e18;
        uint256 secondLoan = 2e18;
        uint256 fees = lender.flashFee(asset, firstLoan) + lender.flashFee(asset, secondLoan);
        IERC20(asset).transfer(address(borrower), fees);
        borrower.flashBorrowAndReenter(asset, firstLoan);

        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(asset));
        assertEq(borrower.flashAmount(), firstLoan + secondLoan);
        assertEq(borrower.flashBalance(), firstLoan + secondLoan + fees); // The amount we transferred to pay for fees,
            // plus the amount we borrowed
        assertEq(borrower.flashFee(), fees);
        assertEq(IERC20(asset).balanceOf(address(lender)), lenderBalance + fees);
    }
}
