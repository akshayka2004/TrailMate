/**
 * Shared base-map tile config, mirroring the mobile app's map_tiles.dart.
 *
 * CARTO's free basemaps.cartocdn.com tiles require an API key (unauthenticated
 * requests return a 200 OK placeholder image reading "API KEY REQUIRED").
 * Default to raw OpenStreetMap tiles (verified working, no key needed); use
 * CARTO only if a key is supplied via VITE_CARTO_API_KEY.
 */
const cartoKey = import.meta.env.VITE_CARTO_API_KEY as string | undefined;

export const tileUrl = cartoKey
  ? `https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=${cartoKey}`
  : "https://tile.openstreetmap.org/{z}/{x}/{y}.png";

export const tileAttribution = cartoKey
  ? '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; CARTO'
  : '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';
