import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { useMemo, useState } from "react";
import {
  MapContainer,
  Marker,
  Polyline,
  Popup,
  TileLayer,
  useMapEvents,
} from "react-leaflet";
import { Button, PageHeader, inputClass } from "../components/ui";
import { useCreate, useList, useRemove, useUpdate } from "../hooks/useResource";
import { api } from "../lib/api";
import { tileAttribution, tileUrl } from "../lib/mapTiles";
import type { Building, Checkpoint, Edge } from "../lib/resourceTypes";
import { useQueryClient } from "@tanstack/react-query";

// Plain colored dots instead of Leaflet's default marker+shadow images —
// avoids a Vite/react-leaflet asset-path bundling quirk that otherwise
// serves a malformed doubled URL for the default icon.
function dotIcon(color: string, size = 16) {
  return L.divIcon({
    className: "",
    html: `<div style="width:${size}px;height:${size}px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.5)"></div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}
const checkpointIcon = dotIcon("#22c55e");
const pendingIcon = dotIcon("#f59e0b");
const endpointAIcon = dotIcon("#3b82f6", 20);
const endpointBIcon = dotIcon("#a855f7", 20);
const waypointIcon = dotIcon("#f97316", 10);

const CAMPUS_CENTER: [number, number] = [9.5132, 76.5423];

function ClickToPlace({
  onPick,
}: {
  onPick: (lat: number, lng: number) => void;
}) {
  useMapEvents({
    click: (e) => onPick(e.latlng.lat, e.latlng.lng),
  });
  return null;
}

const baseURL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";

export function CheckpointsPage() {
  const { data: checkpoints } = useList<Checkpoint>("checkpoints");
  const { data: buildings } = useList<Building>("buildings");
  const { data: edges } = useList<Edge>("edges");
  const create = useCreate<Checkpoint, unknown>("checkpoints");
  const remove = useRemove("checkpoints");
  const updateEdge = useUpdate<Edge, { path: [number, number][] | null }>("edges");
  const qc = useQueryClient();

  const [label, setLabel] = useState("");
  const [buildingId, setBuildingId] = useState<string>("");
  const [pending, setPending] = useState<{ lat: number; lng: number } | null>(
    null,
  );

  // Editing an edge's real-path waypoints — mutually exclusive with placing
  // a new checkpoint, since both consume map clicks.
  const [drawingEdgeId, setDrawingEdgeId] = useState<number | null>(null);
  const [draftPath, setDraftPath] = useState<[number, number][]>([]);

  const cpById = useMemo(
    () => new Map(checkpoints?.map((c) => [c.id, c])),
    [checkpoints],
  );
  const drawingEdge = edges?.find((e) => e.id === drawingEdgeId) ?? null;

  function startDrawing(edge: Edge) {
    setPending(null);
    setDrawingEdgeId(edge.id);
    setDraftPath(edge.path ?? []);
  }

  function cancelDrawing() {
    setDrawingEdgeId(null);
    setDraftPath([]);
  }

  async function saveDrawing() {
    if (drawingEdgeId == null) return;
    await updateEdge.mutateAsync({
      id: drawingEdgeId,
      input: { path: draftPath.length > 0 ? draftPath : null },
    });
    cancelDrawing();
  }

  function handleMapClick(lat: number, lng: number) {
    if (drawingEdgeId != null) {
      setDraftPath((p) => [...p, [lat, lng]]);
    } else {
      setPending({ lat, lng });
    }
  }

  async function confirmPlace() {
    if (!pending || !label.trim()) return;
    await create.mutateAsync({
      label: label.trim(),
      lat: pending.lat,
      lng: pending.lng,
      building_id: buildingId ? Number(buildingId) : null,
    });
    setLabel("");
    setPending(null);
  }

  async function generateQr(id: number) {
    await api.post(`/checkpoints/${id}/qr`);
    qc.invalidateQueries({ queryKey: ["checkpoints"] });
  }

  return (
    <>
      <PageHeader title="Checkpoints" />
      <div className="grid grid-cols-1 gap-4 p-6 lg:grid-cols-[1fr_320px]">
        <div className="h-[70vh] overflow-hidden rounded-xl border border-slate-800">
          <MapContainer
            center={CAMPUS_CENTER}
            zoom={17}
            style={{ height: "100%", width: "100%" }}
          >
            <TileLayer attribution={tileAttribution} url={tileUrl} />
            <ClickToPlace onPick={handleMapClick} />
            {checkpoints?.map((c) => {
              const isEndpointA = drawingEdge?.checkpoint_a_id === c.id;
              const isEndpointB = drawingEdge?.checkpoint_b_id === c.id;
              return (
                <Marker
                  key={c.id}
                  position={[c.lat, c.lng]}
                  icon={
                    isEndpointA ? endpointAIcon : isEndpointB ? endpointBIcon : checkpointIcon
                  }
                >
                  <Popup>
                    <strong>{c.label}</strong>
                    {isEndpointA && " (A — path start)"}
                    {isEndpointB && " (B — path end)"}
                    <br />
                    {c.lat.toFixed(5)}, {c.lng.toFixed(5)}
                  </Popup>
                </Marker>
              );
            })}
            {pending && (
              <Marker position={[pending.lat, pending.lng]} icon={pendingIcon} />
            )}
            {drawingEdgeId != null && draftPath.length > 0 && (
              <>
                <Polyline
                  positions={draftPath}
                  pathOptions={{ color: "#f97316", weight: 4, dashArray: "6 6" }}
                />
                {draftPath.map((p, i) => (
                  <Marker key={i} position={p} icon={waypointIcon} />
                ))}
              </>
            )}
          </MapContainer>
        </div>

        <div className="flex flex-col gap-4">
          {drawingEdgeId != null ? (
            <div className="rounded-xl border border-orange-700 bg-orange-950/40 p-4">
              <p className="mb-2 text-sm font-medium text-orange-200">
                Drawing path: {cpById.get(drawingEdge?.checkpoint_a_id ?? -1)?.label}{" "}
                <span className="text-blue-400">(A)</span> →{" "}
                {cpById.get(drawingEdge?.checkpoint_b_id ?? -1)?.label}{" "}
                <span className="text-purple-400">(B)</span>
              </p>
              <p className="mb-3 text-xs text-orange-300/80">
                Click the map to trace the real walkway from A to B, one point at a
                time. {draftPath.length} point{draftPath.length === 1 ? "" : "s"} placed.
              </p>
              <div className="flex flex-wrap gap-2">
                <Button onClick={saveDrawing} disabled={updateEdge.isPending}>
                  Save path
                </Button>
                <Button
                  variant="ghost"
                  onClick={() => setDraftPath((p) => p.slice(0, -1))}
                  disabled={draftPath.length === 0}
                >
                  Undo point
                </Button>
                <Button variant="ghost" onClick={() => setDraftPath([])}>
                  Clear
                </Button>
                <Button variant="ghost" onClick={cancelDrawing}>
                  Cancel
                </Button>
              </div>
            </div>
          ) : (
            <div className="rounded-xl border border-slate-800 bg-secondary/40 p-4">
              <p className="mb-2 text-sm font-medium text-slate-300">
                Place checkpoint
              </p>
              <p className="mb-3 text-xs text-slate-500">
                Click the map to pick a location, then name it.
              </p>
              <input
                className={`${inputClass} mb-2 w-full`}
                placeholder="Label (e.g. Main Gate)"
                value={label}
                onChange={(e) => setLabel(e.target.value)}
              />
              <select
                className={`${inputClass} mb-2 w-full`}
                value={buildingId}
                onChange={(e) => setBuildingId(e.target.value)}
              >
                <option value="">Outdoor (no building)</option>
                {buildings?.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
              {pending ? (
                <div className="text-xs text-slate-400">
                  Picked {pending.lat.toFixed(5)}, {pending.lng.toFixed(5)}
                  <div className="mt-2">
                    <Button onClick={confirmPlace} disabled={!label.trim()}>
                      Save checkpoint
                    </Button>
                  </div>
                </div>
              ) : (
                <p className="text-xs text-slate-500">No location picked yet.</p>
              )}
            </div>
          )}

          <div className="rounded-xl border border-slate-800 bg-secondary/40 p-4">
            <p className="mb-2 text-sm font-medium text-slate-300">
              Edges ({edges?.length ?? 0})
            </p>
            <p className="mb-3 text-xs text-slate-500">
              A route only hugs real paths for edges with a drawn path — otherwise
              it's a straight line between the two checkpoints.
            </p>
            <ul className="flex max-h-[24vh] flex-col gap-2 overflow-auto">
              {edges?.map((e) => (
                <li key={e.id} className="flex items-center justify-between gap-2 text-sm">
                  <span className="truncate">
                    {cpById.get(e.checkpoint_a_id)?.label ?? e.checkpoint_a_id} →{" "}
                    {cpById.get(e.checkpoint_b_id)?.label ?? e.checkpoint_b_id}{" "}
                    <span className="text-xs text-slate-500">
                      ({Math.round(e.distance_meters)}m{e.path ? ", path set" : ""})
                    </span>
                  </span>
                  <button
                    type="button"
                    onClick={() => startDrawing(e)}
                    className="shrink-0 cursor-pointer rounded-md border border-slate-700 px-2 py-1 text-xs text-slate-300 hover:border-slate-500"
                  >
                    {e.path ? "Edit path" : "Draw path"}
                  </button>
                </li>
              ))}
              {edges?.length === 0 && (
                <li className="text-xs text-slate-500">No edges yet — connect checkpoints on the Route graph page.</li>
              )}
            </ul>
          </div>

          <div className="rounded-xl border border-slate-800 bg-secondary/40 p-4">
            <p className="mb-2 text-sm font-medium text-slate-300">
              All checkpoints ({checkpoints?.length ?? 0})
            </p>
            <ul className="flex max-h-[36vh] flex-col gap-2 overflow-auto">
              {checkpoints?.map((c) => (
                <li
                  key={c.id}
                  className="flex items-center justify-between gap-2 text-sm"
                >
                  <span className="truncate">{c.label}</span>
                  <span className="flex shrink-0 gap-1">
                    {c.qr_code_id ? (
                      <a
                        href={`${baseURL}/checkpoints/${c.id}/qr.png`}
                        target="_blank"
                        rel="noreferrer"
                        className="cursor-pointer rounded-md border border-slate-700 px-2 py-1 text-xs text-accent hover:border-slate-500"
                      >
                        QR
                      </a>
                    ) : (
                      <button
                        type="button"
                        onClick={() => generateQr(c.id)}
                        className="cursor-pointer rounded-md border border-slate-700 px-2 py-1 text-xs text-slate-300 hover:border-slate-500"
                      >
                        Gen QR
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => remove.mutate(c.id)}
                      className="cursor-pointer rounded-md px-2 py-1 text-xs text-destructive hover:bg-destructive/10"
                    >
                      Del
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </>
  );
}
