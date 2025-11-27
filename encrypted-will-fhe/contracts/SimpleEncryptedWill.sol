// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Simple Encrypted Will (off-chain FHE, on-chain storage)
/// @notice 合約只存「加密後的遺囑內容 / 條件」，真正的加解密與判斷交給 Zama FHE SDK 在鏈外處理。
contract SimpleEncryptedWill {
    struct Will {
        address testator;        // 立遺囑人
        address beneficiary;     // 受益人
        bytes conditionCipher;   // 加密條件（例如 FHE 結果、或加密 flag）
        bytes payloadCipher;     // 加密遺囑內容（例如 AES/FHE 後的字串）
        bool unlocked;           // 是否已解鎖（由鏈外 FHE 判斷後來改）
        bool executed;           // 受益人是否已執行 / 領取
    }

    uint256 public nextId;
    mapping(uint256 => Will) public wills;

    event WillCreated(uint256 indexed id, address indexed testator, address indexed beneficiary);
    event WillUnlocked(uint256 indexed id);
    event WillExecuted(uint256 indexed id);

    /// @notice 建立加密遺囑
    /// @param beneficiary 受益人
    /// @param conditionCipher 加密條件（前端用 Zama FHE / 其它方式加密後的 bytes）
    /// @param payloadCipher 加密遺囑內容（例如 JSON -> 加密 -> bytes）
    function createWill(
        address beneficiary,
        bytes calldata conditionCipher,
        bytes calldata payloadCipher
    ) external returns (uint256 id) {
        require(beneficiary != address(0), "INVALID_BENEFICIARY");

        id = nextId++;
        wills[id] = Will({
            testator: msg.sender,
            beneficiary: beneficiary,
            conditionCipher: conditionCipher,
            payloadCipher: payloadCipher,
            unlocked: false,
            executed: false
        });

        emit WillCreated(id, msg.sender, beneficiary);
    }

    /// @notice 當鏈外用 FHE 判斷「條件已滿足」時，由可信執行人或 oracle 來呼叫這個方法。
    function unlockWill(uint256 id) external {
        Will storage w = wills[id];
        require(w.testator != address(0), "WILL_NOT_FOUND");
        require(!w.unlocked, "ALREADY_UNLOCKED");

        // 這裡不做任何條件判斷，僅作為鏈外 FHE 的結果寫入點
        w.unlocked = true;

        emit WillUnlocked(id);
    }

    /// @notice 受益人宣告「已依遺囑領取」
    function markExecuted(uint256 id) external {
        Will storage w = wills[id];
        require(msg.sender == w.beneficiary, "NOT_BENEFICIARY");
        require(w.unlocked, "NOT_UNLOCKED");
        require(!w.executed, "ALREADY_EXECUTED");

        w.executed = true;
        emit WillExecuted(id);
    }

    /// @notice 讀取加密遺囑內容（讓受益人或前端拿去做解密）
    function getWill(uint256 id)
        external
        view
        returns (
            address testator,
            address beneficiary,
            bytes memory conditionCipher,
            bytes memory payloadCipher,
            bool unlocked,
            bool executed
        )
    {
        Will storage w = wills[id];
        require(w.testator != address(0), "WILL_NOT_FOUND");

        return (
            w.testator,
            w.beneficiary,
            w.conditionCipher,
            w.payloadCipher,
            w.unlocked,
            w.executed
        );
    }
}
