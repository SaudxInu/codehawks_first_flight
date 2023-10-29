// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract DeployPuppyRaffle is Script {
    uint256 entranceFee = 1e18;
    address public feeAddress;
    uint256 duration = 1 days;

    function run() public returns (PuppyRaffle, VRFCoordinatorV2Mock) {
        feeAddress = msg.sender;

        vm.broadcast();

        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            0.25 ether,
            1e9
        );

        LinkToken link = new LinkToken();

        uint64 subId = vrfCoordinatorV2Mock.createSubscription();

        vrfCoordinatorV2Mock.fundSubscription(subId, 3 ether);

        PuppyRaffle puppyRaffle = new PuppyRaffle(
            1e18,
            feeAddress,
            duration,
            address(vrfCoordinatorV2Mock),
            subId,
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            500000
        );

        vrfCoordinatorV2Mock.addConsumer(subId, address(puppyRaffle));

        return (puppyRaffle, vrfCoordinatorV2Mock);
    }
}
