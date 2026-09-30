import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, Marker, Polyline, TileLayer, useMap } from "react-leaflet";
import { Link } from "react-router-dom";
import { useQueryClient } from "@tanstack/react-query";
import { BackButton, inputClass } from "../components/ui";
import { api } from "../lib/api";
import { tileAttribution, tileUrl } from "../lib/mapTiles";
import { fetchWalkingPath, haversineMeters, nearestCheckpoint } from "../lib/routing";
import { useList } from "../hooks/useResource";
import type {
  Building,
  Checkpoint,
  Department,
  Room,
  RouteResult,
  SearchHit,
} from "../lib/resourceTypes";

// Plain colored dots instead of Leaflet's default marker+shadow images —
// avoids a Vite/react-leaflet asset-path bundling quirk that otherwise
// serves a malformed doubled path for the default icon.
function dotIcon(color: string) {
  return L.divIcon({
    className: "",
    html: `<div style="width:16px;height:16px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.5)"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
}
const originIcon = dotIcon("#22c55e");
const destinationIcon = dotIcon("#ef4444");

// Used only when there are zero checkpoints to average — see campusCenter().
const FALLBACK_CENTER: [number, number] = [9.5132, 76.5423];

/** Average of all checkpoints — mirrors the mobile app's dynamic
 * `campusCenter` getter, so this stays correct as checkpoints are re-pinned
 * instead of drifting from a hardcoded location. */
function campusCenter(checkpoints: Checkpoint[]): [number, number] {
  if (checkpoints.length === 0) return FALLBACK_CENTER;
  const lat = checkpoints.reduce((sum, c) => sum + c.lat, 0) / checkpoints.length;
  const lng = checkpoints.reduce((sum, c) => sum + c.lng, 0) / checkpoints.length;
  return [lat, lng];
}

// Snapping the GPS fix to a checkpoint further than this away would silently
// mislead the user about where the route actually starts from.
const MAX_ORIGIN_SNAP_METERS = 500;

function buildHits(
  query: string,
  buildings: Building[],
  rooms: Room[],
  departments: Department[],
  checkpoints: Checkpoint[],
): SearchHit[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  const buildingById = new Map(buildings.map((b) => [b.id, b]));
  const hits: SearchHit[] = [];

  for (const b of buildings) {
    if (b.name.toLowerCase().includes(q)) {
      hits.push({ title: b.name, subtitle: "Building", lat: b.lat, lng: b.lng });
    }
  }
  for (const r of rooms) {
    if (r.name.toLowerCase().includes(q)) {
      const b = buildingById.get(r.building_id);
      if (b) {
        hits.push({
          title: r.name,
          subtitle: `${r.type.replace("_", " ")} · ${b.name}`,
          lat: b.lat,
          lng: b.lng,
        });
      }
    }
  }
  for (const d of departments) {
    if (d.name.toLowerCase().includes(q)) {
      const b = buildingById.get(d.building_id);
      if (b) {
        hits.push({ title: d.name, subtitle: `Department · ${b.name}`, lat: b.lat, lng: b.lng });
      }
    }
  }
  // Checkpoints are real navigable points too — a campus with checkpoints
  // pinned but no buildings/rooms/departments yet would otherwise be
  // completely unsearchable.
  for (const c of checkpoints) {
    if (c.label.toLowerCase().includes(q)) {
      hits.push({ title: c.label, subtitle: "Checkpoint", lat: c.lat, lng: c.lng });
    }
  }
  return hits;
}

function RecenterOnRoute({ points }: { points: [number, number][] }) {
  const map = useMap();
  useMemo(() => {
    if (points.length > 1) {
      map.fitBounds(L.latLngBounds(points), { padding: [48, 48] });
    }
  }, [map, points]);
  return null;
}

/** react-leaflet ignores changes to MapContainer's `center` prop after
 * mount, so once checkpoints load asynchronously (initial render has none)
 * the map needs an explicit pan to the real campus center. Only does this
 * once, so it doesn't fight the user's own panning/zooming on later polls. */
function RecenterOnData({ center, ready }: { center: [number, number]; ready: boolean }) {
  const map = useMap();
  const done = useRef(false);
  useEffect(() => {
    if (ready && !done.current) {
      done.current = true;
      map.setView(center, 17);
    }
  }, [map, center, ready]);
  return null;
}

function refreshAll(qc: ReturnType<typeof useQueryClient>) {
  for (const key of ["buildings", "rooms", "departments", "checkpoints"]) {
    qc.invalidateQueries({ queryKey: [key] });
  }
}

export function FindPage() {
  const qc = useQueryClient();
  // Poll while this page is open — an admin adding checkpoints is almost
  // always a different browser/device, so there's no shared cache to
  // invalidate into. 15s keeps new pins showing up without a manual reload.
  const pollOptions = { refetchInterval: 15000 };
  const { data: buildings = [] } = useList<Building>("buildings", pollOptions);
  const { data: rooms = [] } = useList<Room>("rooms", pollOptions);
  const { data: departments = [] } = useList<Department>("departments", pollOptions);
  const { data: checkpoints = [] } = useList<Checkpoint>("checkpoints", pollOptions);

  const [query, setQuery] = useState("");
  const [destination, setDestination] = useState<SearchHit | null>(null);
  const [origin, setOrigin] = useState<{ lat: number; lng: number } | null>(null);
  const [route, setRoute] = useState<RouteResult | null>(null);
  const [walkingPath, setWalkingPath] = useState<[number, number][] | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Default view (no search yet) lists every building AND every checkpoint
  // so available destinations are visible immediately — a campus with
  // checkpoints pinned but no buildings yet would otherwise show nothing.
  const hits = query.trim()
    ? buildHits(query, buildings, rooms, departments, checkpoints)
    : [
        ...buildings.map((b) => ({ title: b.name, subtitle: "Building", lat: b.lat, lng: b.lng })),
        ...checkpoints.map((c) => ({ title: c.label, subtitle: "Checkpoint", lat: c.lat, lng: c.lng })),
      ];

  async function navigateTo(hit: SearchHit) {
    setDestination(hit);
    setRoute(null);
    setWalkingPath(null);
    setError(null);
    setNotice(null);
    setBusy(true);

    const pos = await getBrowserLocation();
    const center = campusCenter(checkpoints);
    const originPoint = pos ?? { lat: center[0], lng: center[1] };
    setOrigin(originPoint);

    const originCp = nearestCheckpoint(checkpoints, originPoint.lat, originPoint.lng);
    const destCp = nearestCheckpoint(checkpoints, hit.lat, hit.lng);
    if (!originCp || !destCp) {
      setError("No checkpoints available to route through.");
      setBusy(false);
      return;
    }

    if (!pos) {
      setNotice("Could not get your location — routing from campus center instead.");
    } else {
      const snapDistance = haversineMeters(pos, originCp);
      if (snapDistance > MAX_ORIGIN_SNAP_METERS) {
        setNotice(
          `You're ${(snapDistance / 1000).toFixed(1)} km from the nearest checkpoint ` +
            `(${originCp.label}) — route may not reflect your real position.`,
        );
      }
    }

    try {
      const { data } = await api.get<RouteResult>("/route", {
        params: { from_id: originCp.id, to_id: destCp.id },
      });
      setRoute(data);
    } catch {
      setError("Could not compute a route between those points.");
      setBusy(false);
      return;
    }

    // Real path-following geometry, if an ORS key is configured — falls back
    // to the checkpoint-graph straight line (from `route.steps`) otherwise.
    const walking = await fetchWalkingPath(originPoint, hit);
    if (walking) setWalkingPath(walking.points);

    setBusy(false);
  }

  // route.polyline already includes each edge's real-path waypoints where an
  // admin has drawn them; walkingPath (OpenRouteService) takes priority when
  // configured since it follows the actual OSM path network.
  const graphPolyline: [number, number][] = route?.polyline ?? [];
  const polylinePoints = walkingPath ?? graphPolyline;

  return (
    <main className="flex min-h-dvh flex-col bg-background text-foreground">
      <header className="flex items-center justify-between border-b border-slate-800 px-6 py-4">
        <div className="flex items-center gap-2">
          <BackButton fallback="/find" />
          <h1 className="font-heading text-xl font-semibold tracking-tight">
            TrailMate — Find your way
          </h1>
        </div>
        <div className="flex items-center gap-4">
          <button
            type="button"
            onClick={() => refreshAll(qc)}
            className="cursor-pointer text-xs text-slate-500 hover:text-slate-300"
          >
            Refresh
          </button>
          <Link to="/login" className="text-xs text-slate-500 hover:text-slate-300">
            Admin sign in
          </Link>
        </div>
      </header>

      <div className="grid flex-1 grid-cols-1 gap-4 p-6 lg:grid-cols-[320px_1fr]">
        <div className="flex flex-col gap-3">
          <input
            className={`${inputClass} w-full`}
            placeholder="Search buildings, rooms, departments"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <ul className="flex max-h-[50vh] flex-col gap-1 overflow-auto rounded-xl border border-slate-800">
            {hits.length === 0 ? (
              <li className="px-3 py-2 text-sm text-slate-500">
                {query ? "No matches" : "No destinations yet"}
              </li>
            ) : (
              hits.map((hit, i) => (
                <li key={i}>
                  <button
                    type="button"
                    onClick={() => navigateTo(hit)}
                    className="w-full cursor-pointer px-3 py-2 text-left text-sm hover:bg-secondary/60"
                  >
                    <div className="font-medium">{hit.title}</div>
                    <div className="text-xs text-slate-500">{hit.subtitle}</div>
                  </button>
                </li>
              ))
            )}
          </ul>

          {notice && (
            <div className="rounded-lg border border-orange-800 bg-orange-950/60 px-3 py-2 text-xs text-orange-200">
              {notice}
            </div>
          )}
          {error && (
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
              {error}
            </div>
          )}
          {route && (
            <div className="rounded-lg border border-slate-800 bg-secondary/40 px-3 py-3 text-sm">
              <div className="font-medium">{destination?.title}</div>
              <div className="text-xs text-slate-400">
                {route.steps.length < 2
                  ? "You're already at this destination."
                  : `${route.steps.length} stops · ${Math.round(route.total_distance_meters)} m · ` +
                    `${Math.ceil(route.total_time_seconds / 60)} min walk`}
              </div>
              {walkingPath && (
                <div className="mt-1 text-xs text-accent">Path-following route (OpenRouteService)</div>
              )}
            </div>
          )}
          {busy && <div className="text-xs text-slate-500">Locating you…</div>}
        </div>

        <div className="h-[70vh] overflow-hidden rounded-xl border border-slate-800 lg:h-full">
          <MapContainer
            center={FALLBACK_CENTER}
            zoom={17}
            style={{ height: "100%", width: "100%" }}
          >
            <TileLayer attribution={tileAttribution} url={tileUrl} />
            {polylinePoints.length < 2 && (
              <RecenterOnData center={campusCenter(checkpoints)} ready={checkpoints.length > 0} />
            )}
            {polylinePoints.length > 1 && (
              <Polyline positions={polylinePoints} pathOptions={{ color: "#22c55e", weight: 5 }} />
            )}
            {polylinePoints.length > 1 && <RecenterOnRoute points={polylinePoints} />}
            {origin && <Marker position={[origin.lat, origin.lng]} icon={originIcon} />}
            {destination && (
              <Marker position={[destination.lat, destination.lng]} icon={destinationIcon} />
            )}
          </MapContainer>
        </div>
      </div>
    </main>
  );
}

function getBrowserLocation(): Promise<{ lat: number; lng: number } | null> {
  return new Promise((resolve) => {
    if (!navigator.geolocation) {
      resolve(null);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 6000 },
    );
  });
}
