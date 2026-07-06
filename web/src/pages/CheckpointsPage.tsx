import L from "leaflet";
import markerIcon2x from "leaflet/dist/images/marker-icon-2x.png";
import markerIcon from "leaflet/dist/images/marker-icon.png";
import markerShadow from "leaflet/dist/images/marker-shadow.png";
import "leaflet/dist/leaflet.css";
import { useState } from "react";
import {
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMapEvents,
} from "react-leaflet";
import { Button, PageHeader, inputClass } from "../components/ui";
import { useCreate, useList, useRemove } from "../hooks/useResource";
import { api } from "../lib/api";
import type { Building, Checkpoint } from "../lib/resourceTypes";
import { useQueryClient } from "@tanstack/react-query";

// Vite bundles marker images as URLs; rewire Leaflet's default icon paths.
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
});

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
  const create = useCreate<Checkpoint, unknown>("checkpoints");
  const remove = useRemove("checkpoints");
  const qc = useQueryClient();

  const [label, setLabel] = useState("");
  const [buildingId, setBuildingId] = useState<string>("");
  const [pending, setPending] = useState<{ lat: number; lng: number } | null>(
    null,
  );

  async function placeCheckpoint(lat: number, lng: number) {
    setPending({ lat, lng });
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
            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <ClickToPlace onPick={placeCheckpoint} />
            {checkpoints?.map((c) => (
              <Marker key={c.id} position={[c.lat, c.lng]}>
                <Popup>
                  <strong>{c.label}</strong>
                  <br />
                  {c.lat.toFixed(5)}, {c.lng.toFixed(5)}
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        <div className="flex flex-col gap-4">
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
