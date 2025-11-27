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
        <textarea v-model="payloadPlain" rows="3"
                  class="border w-full px-2 py-1 rounded" />
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
        <input v-model.number="unlockId" type="number"
               class="border w-full px-2 py-1 rounded" />
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
        <input v-model.number="queryId" type="number"
               class="border w-full px-2 py-1 rounded" />
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


// 你前面部署的地址
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

let provider: BrowserProvider;
let signer: any;
let contract: Contract;

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
  contract = new Contract(CONTRACT_ADDRESS, abi, signer);

  message.value = "Wallet connected: " + account.value;
}

async function createWill() {
  if (!connected.value) return;

  const condBytes = toUtf8Bytes(conditionPlain.value);
  const payloadBytes = toUtf8Bytes(payloadPlain.value);

  const tx = await contract.createWill(
    beneficiary.value,
    "0x" + Buffer.from(condBytes).toString("hex"),
    "0x" + Buffer.from(payloadBytes).toString("hex")
  );
  await tx.wait();

  const nextId = await contract.nextId();
  createdId.value = Number(nextId) - 1;

  message.value = "Will created";
}

async function unlockWill() {
  if (!connected.value || unlockId.value === null) return;

  const tx = await contract.unlockWill(unlockId.value);
  await tx.wait();

  message.value = "Will unlocked";
}

async function getWill() {
  if (!connected.value || queryId.value === null) return;

  const result = await contract.getWill(queryId.value);
  const [testator, bene, condCipher, payloadCipher, unlocked, executed] = result;

  let condText = "";
  let payloadText = "";

  try { condText = toUtf8String(condCipher); } catch {}
  try { payloadText = toUtf8String(payloadCipher); } catch {}

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
