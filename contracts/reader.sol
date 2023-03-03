// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleDrop is ERC20 {
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function addTokensFromCSV(string memory csv) public {
        require(merkleRoot == 0, "Tokens already distributed");

        bytes memory csvBytes = bytes(csv);
        bytes32[] memory hashes = new bytes32[](csvBytes.length);
        uint256 totalTokens = 0;

        uint256 addressStartIndex = 0;
        uint256 amountStartIndex = 0;
        uint256 currentIndex = 0;

        while (currentIndex < csvBytes.length) {
            if (csvBytes[currentIndex] == ",") {
                bytes memory addressBytes = new bytes(currentIndex - addressStartIndex);
                bytes memory amountBytes = new bytes(currentIndex - amountStartIndex);

                for (uint256 i = 0; i < currentIndex - addressStartIndex; i++) {
                    addressBytes[i] = csvBytes[addressStartIndex + i];
                }

                for (uint256 i = 0; i < currentIndex - amountStartIndex; i++) {
                    amountBytes[i] = csvBytes[amountStartIndex + i];
                }

                address addr = bytesToAddress(addressBytes);
                uint256 amount = bytesToUint(amountBytes);

                hashes[totalTokens] = keccak256(abi.encodePacked(addr, amount));
                totalTokens += amount;

                addressStartIndex = currentIndex + 1;
                amountStartIndex = currentIndex + 1;
            } else if (csvBytes[currentIndex] == "\n") {
                amountStartIndex = currentIndex + 1;
            }

            currentIndex++;
        }

       merkleRoot = keccak256(abi.encodePacked(MerkleProof.computeRoot(hashes)));

        _mint(address(this), totalTokens);
    }

    function claimTokens(uint256 amount, bytes32[] memory merkleProof) public {
        require(merkleRoot != 0, "Tokens not yet distributed");
        require(!claimed[msg.sender], "Tokens already claimed");

        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof");

        claimed[msg.sender] = true;
        transfer(msg.sender, amount);
    }

    function bytesToAddress(bytes memory data) private pure returns (address addr) {
        assembly {
            addr := mload(add(data, 20))
        }
    }

    function bytesToUint(bytes memory data) private pure returns (uint256 value) {
        assembly {
            value := mload(add(data, 32))
        }
    }
}
