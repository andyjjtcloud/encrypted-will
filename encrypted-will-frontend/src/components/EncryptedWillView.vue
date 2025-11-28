<template> 
  <div class="p-4 space-y-4">
    <h1 class="text-xl font-bold">🔐 Simple Encrypted Will (Sepolia)</h1>

    <!-- 連接錢包 -->
    <div>
      <button @click="connectWallet" class="border px-3 py-1 rounded">
        {{ connected ? 'Connected: ' + shortAddr : 'Connect Wallet' }}
      </button>
    </div>

    <!-- 建立遺囑 -->
    <div class="border rounded p-3 space-y-2">
      <h2 class="font-semibold">1️⃣ Create Encrypted Will</h2>

      <label class="block">
        Beneficiary Address
        <input v-model="beneficiary" class="border w-full px-2 py-1 rounded" />
      </label>

      <label class="block">
        Condition (plain text, demo)
        <input v-model="conditionPlain" class="border w-full px-2 py-1 rounded" />
      </label>

      <label class="block">
        Will Content (plain text, demo)
        <textarea
          v-model="payloadPlain"
          rows="3"
          class="border w-full px-2 py-1 rounded"
        />
      </label>

      <button @click="createWill" class="border px-3 py-1 rounded">
        Create Encrypted Will
      </button>

      <p v-if="createdId !== null" class="text-green-600">
        ✅ Created Will ID: {{ createdId }}
      </p>
    </div>

    <!-- 解鎖遺囑 -->
    <div class="border rounded p-3 space-y-2">
      <h2 class="font-semibold">2️⃣ Unlock Will</h2>

      <label class="block">
        Will ID
        <input
          v-model.number="unlockId"
          type="number"
          class="border w-full px-2 py-1 rounded"
        />
      </label>

      <button @click="unlockWill" class="border px-3 py-1 rounded">
        Unlock Will
      </button>
    </div>

    <!-- 查詢遺囑 -->
    <div class="border rounded p-3 space-y-2">
      <h2 class="font-semibold">3️⃣ Get Will</h2>

      <label class="block">
        Will ID
        <input
          v-model.number="queryId"
          type="number"
          class="border w-full px-2 py-1 rounded"
        />
      </label>

      <button @click="getWill" class="border px-3 py-1 rounded">
        Get Will
      </button>

      <div v-if="willInfo" class="mt-2 text-sm space-y-1">
        <p><b>Testator:</b> {{ willInfo.testator }}</p>
        <p><b>Beneficiary:</b> {{ willInfo.beneficiary }}</p>
        <p><b>Unlocked:</b> {{ willInfo.unlocked }}</p>
        <p><b>Executed:</b> {{ willInfo.executed }}</p>
        <p><b>Condition:</b> {{ willInfo.conditionPlain }}</p>
        <p><b>Payload:</b> {{ willInfo.payloadPlain }}</p>
      </div>
    </div>

    <p v-if="message" class="text-xs text-gray-500">Log: {{ message }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { BrowserProvider, Contract, toUtf8Bytes, toUtf8String } from "ethers";
import SimpleEncryptedWillJson from "../contracts/SimpleEncryptedWill.json";

// 針對這份合約定義一個型別，避免 TS 覺得方法可能不存在
interface SimpleEncryptedWillContract extends Contract {
  createWill(
    beneficiary: string,
    conditionCipher: Uint8Array,
    payloadCipher: Uint8Array
  ): Promise<any>;
  nextId(): Promise<bigint>;
  unlockWill(id: number): Promise<any>;
  getWill(id: number): Promise<any>;
}

// 你部署的地址
const CONTRACT_ADDRESS = "0x7C5c5170bB940AECb47A651d7FC954D5fCE398cD";

const connected = ref(false);
const account = ref<string | null>(null);
const message = ref("");

const beneficiary = ref("");
const conditionPlain = ref("");
const payloadPlain = ref("");

const createdId = ref<number | null>(null);
const unlockId = ref<number | null>(null);
const queryId = ref<number | null>(null);

const willInfo = ref<null | {
  testator: string;
  beneficiary: string;
  conditionPlain: string;
  payloadPlain: string;
  unlocked: boolean;
  executed: boolean;
}>(null);

// 一開始都還是 null，connectWallet 之後才會塞進真正的物件
let provider: BrowserProvider | null = null;
let signer: any | null = null;
let contract: SimpleEncryptedWillContract | null = null;

const shortAddr = computed(() =>
  account.value ? account.value.slice(0, 6) + "..." + account.value.slice(-4) : ""
);

async function connectWallet() {
  if (!(window as any).ethereum) {
    alert("請先安裝 MetaMask");
    return;
  }
  provider = new BrowserProvider((window as any).ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  account.value = await signer.getAddress();
  connected.value = true;

  const abi = (SimpleEncryptedWillJson as any).abi;
  contract = new Contract(
    CONTRACT_ADDRESS,
    abi,
    signer
  ) as SimpleEncryptedWillContract;

  message.value = "Wallet connected: " + account.value;
}

async function createWill() {
  if (!connected.value || !contract) {
    message.value = "請先 Connect Wallet";
    return;
  }

  const condBytes = toUtf8Bytes(conditionPlain.value || "condition-demo");
  const payloadBytes = toUtf8Bytes(payloadPlain.value || "payload-demo");

  const c = contract; // 縮短一下寫法，TS 也可以正確推論
  const tx = await c.createWill(
    beneficiary.value,
    condBytes,
    payloadBytes
  );
  await tx.wait();

  const nextId = await c.nextId();
  createdId.value = Number(nextId) - 1;

  message.value = "Will created";
}

async function unlockWill() {
  if (!connected.value || !contract) {
    message.value = "請先 Connect Wallet";
    return;
  }
  if (unlockId.value === null) {
    alert("請輸入 Will ID");
    return;
  }

  const c = contract;
  const tx = await c.unlockWill(unlockId.value);
  await tx.wait();

  message.value = "Will unlocked";
}

async function getWill() {
  if (!connected.value || !contract) {
    message.value = "請先 Connect Wallet";
    return;
  }
  if (queryId.value === null) {
    alert("請輸入 Will ID");
    return;
  }

  const c = contract;
  const result = await c.getWill(queryId.value);
  const [testator, bene, condCipher, payloadCipher, unlocked, executed] = result as [
    string,
    string,
    Uint8Array,
    Uint8Array,
    boolean,
    boolean
  ];

  let condText = "";
  let payloadText = "";

  try {
    condText = toUtf8String(condCipher);
  } catch {
    condText = "(cannot decode conditionCipher as UTF-8)";
  }
  try {
    payloadText = toUtf8String(payloadCipher);
  } catch {
    payloadText = "(cannot decode payloadCipher as UTF-8)";
  }

  willInfo.value = {
    testator,
    beneficiary: bene,
    conditionPlain: condText,
    payloadPlain: payloadText,
    unlocked,
    executed,
  };

  message.value = "Will loaded";
}
</script>
