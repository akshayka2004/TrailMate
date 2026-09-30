import type { Checkpoint } from "./resourceTypes";

export function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const r = 6371000;
  const p1 = (a.lat * Math.PI) / 180;
  const p2 = (b.lat * Math.PI) / 180;
  const dphi = ((b.lat - a.lat) * Math.PI) / 180;
  const dlmb = ((b.lng - a.lng) * Math.PI) / 180;
  const h =
    Math.sin(dphi / 2) ** 2 +
    Math.cos(p1) * Math.cos(p2) * Math.sin(dlmb / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

export function nearestCheckpoint(
  checkpoints: Checkpoint[],
  lat: number,
  lng: number,
): Checkpoint | null {
  let best: Checkpoint | null = null;
  let bestD = Infinity;
  for (const cp of checkpoints) {
    const d = haversineMeters({ lat, lng }, cp);
    if (d < bestD) {
      bestD = d;
      best = cp;
    }
  }
  return best;
}

/**
 * Real path-following walking route from OpenRouteService (foot-walking
 * profile) — used for the drawn line so it hugs actual paths instead of
 * jumping straight between checkpoint dots. Returns null (caller falls back
 * to the checkpoint-graph straight-line polyline) if no key is configured
 * or the request fails.
 */
export async function fetchWalkingPath(
  origin: { lat: number; lng: number },
  destination: { lat: number; lng: number },
): Promise<{ points: [number, number][]; distanceMeters: number; durationSeconds: number } | null> {
  const key = import.meta.env.VITE_ORS_API_KEY as string | undefined;
  if (!key) return null;
  try {
    const res = await fetch(
      "https://api.openrouteservice.org/v2/directions/foot-walking/geojson",
      {
        method: "POST",
        headers: {
          Authorization: key,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          coordinates: [
            [origin.lng, origin.lat],
            [destination.lng, destination.lat],
          ],
        }),
      },
    );
    if (!res.ok) return null;
    const geojson = await res.json();
    const feature = geojson.features?.[0];
    if (!feature) return null;
    const coords = feature.geometry.coordinates as [number, number][];
    const summary = feature.properties?.summary as
      | { distance: number; duration: number }
      | undefined;
    return {
      points: coords.map(([lng, lat]) => [lat, lng]),
      distanceMeters: summary?.distance ?? 0,
      durationSeconds: summary?.duration ?? 0,
    };
  } catch {
    return null;
  }
}
