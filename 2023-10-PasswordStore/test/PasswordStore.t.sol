// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {PasswordStore} from "../src/PasswordStore.sol";
import {DeployPasswordStore} from "../script/DeployPasswordStore.s.sol";

contract PasswordStoreTest is Test {
    PasswordStore public passwordStore;
    DeployPasswordStore public deployer;
    address public owner;

    function setUp() public {
        deployer = new DeployPasswordStore();
        passwordStore = deployer.run();
        owner = msg.sender;
    }

    function test_owner_can_set_password() public {
        vm.startPrank(owner);
        string memory expectedPassword = "myNewPassword";
        passwordStore.setPassword(expectedPassword);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
    }

    function test_non_owner_reading_password_reverts() public {
        vm.startPrank(address(1));
        vm.expectRevert(PasswordStore.PasswordStore__NotOwner.selector);
        passwordStore.getPassword();
    }

    modifier ownerChangePassword() {
        vm.startPrank(owner);

        passwordStore.setPassword("myNewPassword");

        vm.stopPrank();

        _;
    }

    function test_non_owner_reading_password() public ownerChangePassword {
        vm.startPrank(owner);

        string memory secret_password = passwordStore.getPassword();

        vm.stopPrank();

        // If the string is bigger than 32 bytes, in slot 1, length of the string will be stored
        // and string will be stored from slot number keccak256(abi.encodePacked(1)) till keccak256(abi.encodePacked(1)) + length - 1.
        // So, you need read from those slots and then convert to a string.
        // Please refer https://medium.com/@0xZorz/how-to-read-dynamic-arrays-directly-from-storage-using-foundry-bdf5a104b8f6 for more details.
        string memory retrieved_password =
            string(abi.encodePacked(vm.load(address(passwordStore), bytes32(uint256(1)))));

        console.log(secret_password);

        console.log(retrieved_password);

        // Error - abi.encodePacked is giving different bytes for same string.
        // Just try removing keccak256 and logging the results.
        // abi.encodePacked(secret_password) -> 0x6d794e657750617373776f7264
        // abi.encodePacked(retrieved_password) -> 0x6d794e657750617373776f72640000000000000000000000000000000000001a
        assertEq(keccak256(abi.encodePacked(secret_password)), keccak256(abi.encodePacked(retrieved_password)));
    }
}
