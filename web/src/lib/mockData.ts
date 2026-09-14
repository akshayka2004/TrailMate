// TEMPORARY: backend DB (Supabase) is unreachable. In-memory mock store
// mirroring the real backend seed data (same names/coordinates as
// backend/app/db/seed.py) so the admin portal is demoable offline.
// Remove this file and restore real api.* calls in useResource.ts once the
// backend is back up.
import type { Building, Checkpoint, Department, Edge, Room } from "./resourceTypes";

type Store = {
  buildings: Building[];
  departments: Department[];
  rooms: Room[];
  checkpoints: Checkpoint[];
  edges: Edge[];
};

const WALK_SPEED_M_PER_S = 1.4;

function edge(
  id: number,
  a: number,
  b: number,
  meters: number,
  indoor = false,
): Edge {
  return {
    id,
    checkpoint_a_id: a,
    checkpoint_b_id: b,
    distance_meters: meters,
    walking_time_estimate_sec: Math.trunc(meters / WALK_SPEED_M_PER_S),
    is_indoor: indoor,
  };
}

// `store` is reassigned (never mutated in place) so every read after a
// write sees genuinely new array/object references — otherwise React Query
// treats same-reference data as unchanged and skips re-rendering.
let store: Store = {
  buildings: [
    { id: 1, name: "Admin Block", description: "Administration, principal's office, accounts.", image_url: null, lat: 9.5133, lng: 76.5421 },
    { id: 2, name: "CS Block", description: "Computer Science & Engineering department.", image_url: null, lat: 9.5138, lng: 76.5428 },
    { id: 3, name: "Mechanical Block", description: "Mechanical Engineering department and workshops.", image_url: null, lat: 9.5127, lng: 76.5432 },
    { id: 4, name: "Central Library", description: "Library and reading halls.", image_url: null, lat: 9.5136, lng: 76.5415 },
  ],
  departments: [
    { id: 1, name: "Computer Science & Engineering", building_id: 2 },
    { id: 2, name: "Mechanical Engineering", building_id: 3 },
    { id: 3, name: "Administration", building_id: 1 },
  ],
  rooms: [
    { id: 1, name: "CS-101", type: "classroom", floor: 1, building_id: 2 },
    { id: 2, name: "Programming Lab 1", type: "lab", floor: 1, building_id: 2 },
    { id: 3, name: "CS Seminar Hall", type: "seminar_hall", floor: 2, building_id: 2 },
    { id: 4, name: "Principal's Office", type: "office", floor: 1, building_id: 1 },
    { id: 5, name: "CAD Lab", type: "lab", floor: 1, building_id: 3 },
    { id: 6, name: "Reading Hall", type: "classroom", floor: 1, building_id: 4 },
  ],
  checkpoints: [
    { id: 1, label: "Main Gate", lat: 9.5125, lng: 76.5410, building_id: null, qr_code_id: 1 },
    { id: 2, label: "Junction A (flagpole)", lat: 9.5130, lng: 76.5416, building_id: null, qr_code_id: null },
    { id: 3, label: "Junction B (canteen turn)", lat: 9.5132, lng: 76.5425, building_id: null, qr_code_id: null },
    { id: 4, label: "Junction C (workshop road)", lat: 9.5128, lng: 76.5430, building_id: null, qr_code_id: null },
    { id: 5, label: "Parking Lot", lat: 9.5123, lng: 76.5414, building_id: null, qr_code_id: null },
    { id: 6, label: "Admin Block Entrance", lat: 9.5133, lng: 76.5420, building_id: 1, qr_code_id: 2 },
    { id: 7, label: "Admin Lobby", lat: 9.51335, lng: 76.5422, building_id: 1, qr_code_id: null },
    { id: 8, label: "CS Block Entrance", lat: 9.5137, lng: 76.5427, building_id: 2, qr_code_id: 3 },
    { id: 9, label: "CS Stairwell (Ground)", lat: 9.5138, lng: 76.5429, building_id: 2, qr_code_id: null },
    { id: 10, label: "CS Floor 2 Corridor", lat: 9.51382, lng: 76.54292, building_id: 2, qr_code_id: null },
    { id: 11, label: "Mechanical Block Entrance", lat: 9.5127, lng: 76.5431, building_id: 3, qr_code_id: 4 },
    { id: 12, label: "Workshop Bay", lat: 9.5126, lng: 76.5433, building_id: 3, qr_code_id: null },
    { id: 13, label: "Library Entrance", lat: 9.5135, lng: 76.5416, building_id: 4, qr_code_id: 5 },
    { id: 14, label: "Reading Hall Door", lat: 9.5136, lng: 76.5414, building_id: 4, qr_code_id: null },
    { id: 15, label: "Canteen", lat: 9.5134, lng: 76.5424, building_id: null, qr_code_id: null },
  ],
  edges: [
    edge(1, 1, 2, 85),
    edge(2, 1, 5, 60),
    edge(3, 2, 3, 100),
    edge(4, 3, 4, 70),
    edge(5, 2, 13, 55),
    edge(6, 2, 6, 50),
    edge(7, 3, 8, 45),
    edge(8, 3, 15, 30),
    edge(9, 4, 11, 25),
    edge(10, 6, 7, 15, true),
    edge(11, 8, 9, 20, true),
    edge(12, 9, 10, 12, true),
    edge(13, 11, 12, 30, true),
    edge(14, 13, 14, 18, true),
    edge(15, 15, 8, 40),
    edge(16, 5, 2, 70),
  ],
};

const nextId: Record<keyof Store, number> = {
  buildings: 5,
  departments: 4,
  rooms: 7,
  checkpoints: 16,
  edges: 17,
};

let nextQrId = 6;

function key(resource: string): keyof Store {
  if (resource in store) return resource as keyof Store;
  throw new Error(`Unknown mock resource: ${resource}`);
}

export function mockList<T>(resource: string): T[] {
  // Fresh array reference every call so React Query always sees "new" data.
  return [...(store[key(resource)] as unknown as T[])];
}

export function mockCreate<T extends { id: number }>(
  resource: string,
  input: Record<string, unknown>,
): T {
  const k = key(resource);
  const record = { id: nextId[k]++, ...input } as unknown as T;
  store = { ...store, [k]: [...(store[k] as unknown as T[]), record] };
  return record;
}

export function mockUpdate<T extends { id: number }>(
  resource: string,
  id: number,
  input: Record<string, unknown>,
): T {
  const k = key(resource);
  const arr = store[k] as unknown as T[];
  const idx = arr.findIndex((r) => r.id === id);
  if (idx === -1) throw new Error(`Not found: ${resource}#${id}`);
  const updated = { ...arr[idx], ...input };
  const nextArr = [...arr];
  nextArr[idx] = updated;
  store = { ...store, [k]: nextArr };
  return updated;
}

export function mockRemove(resource: string, id: number): void {
  const k = key(resource);
  const arr = store[k] as unknown as { id: number }[];
  store = { ...store, [k]: arr.filter((r) => r.id !== id) };
}

/** Checkpoints-page-only helper: simulates POST /checkpoints/{id}/qr. */
export function mockGenerateQr(checkpointId: number): void {
  const arr = store.checkpoints;
  const idx = arr.findIndex((c) => c.id === checkpointId);
  if (idx === -1) return;
  const nextArr = [...arr];
  nextArr[idx] = { ...arr[idx], qr_code_id: nextQrId++ };
  store = { ...store, checkpoints: nextArr };
}
