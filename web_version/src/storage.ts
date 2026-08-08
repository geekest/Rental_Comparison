import type { AppState } from "./domain";

const DB_NAME = "rental-comparison-local";
const DB_VERSION = 1;
const STATE_STORE = "state";
const MEDIA_STORE = "media";

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(STATE_STORE)) database.createObjectStore(STATE_STORE);
      if (!database.objectStoreNames.contains(MEDIA_STORE)) database.createObjectStore(MEDIA_STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function transaction<T>(
  storeName: string,
  mode: IDBTransactionMode,
  action: (store: IDBObjectStore) => IDBRequest<T>,
) {
  const database = await openDatabase();
  return new Promise<T>((resolve, reject) => {
    const tx = database.transaction(storeName, mode);
    const request = action(tx.objectStore(storeName));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    tx.oncomplete = () => database.close();
    tx.onerror = () => reject(tx.error);
  });
}

export async function loadState(): Promise<AppState | undefined> {
  return transaction<AppState | undefined>(STATE_STORE, "readonly", (store) => store.get("app"));
}

export async function saveState(state: AppState): Promise<void> {
  await transaction<IDBValidKey>(STATE_STORE, "readwrite", (store) => store.put(state, "app"));
}

export async function saveMedia(file: Blob): Promise<string> {
  const id = crypto.randomUUID();
  await transaction<IDBValidKey>(MEDIA_STORE, "readwrite", (store) => store.put(file, id));
  return id;
}

export async function loadMedia(id: string): Promise<Blob | undefined> {
  return transaction<Blob | undefined>(MEDIA_STORE, "readonly", (store) => store.get(id));
}
