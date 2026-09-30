import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import { tileAttribution, tileUrl } from "../lib/mapTiles";

const CAMPUS_CENTER: [number, number] = [9.5132, 76.5423];

const pinIcon = L.divIcon({
  className: "",
  html: '<div style="width:16px;height:16px;border-radius:50%;background:#22c55e;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.5)"></div>',
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});

function ClickCapture({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onPick(e.latlng.lat, e.latlng.lng) });
  return null;
}

/** Click-to-place map for picking a lat/lng — used wherever a form needs
 * real-world coordinates instead of making someone type decimal degrees. */
export function LocationPicker({
  value,
  onChange,
  center = CAMPUS_CENTER,
  height = 260,
}: {
  value: { lat: number; lng: number } | null;
  onChange: (lat: number, lng: number) => void;
  center?: [number, number];
  height?: number;
}) {
  return (
    <div
      className="overflow-hidden rounded-lg border border-slate-700"
      style={{ height }}
    >
      <MapContainer
        center={value ?? center}
        zoom={17}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer attribution={tileAttribution} url={tileUrl} />
        <ClickCapture onPick={onChange} />
        {value && <Marker position={[value.lat, value.lng]} icon={pinIcon} />}
      </MapContainer>
    </div>
  );
}
