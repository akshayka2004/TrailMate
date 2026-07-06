export type RoomType = "classroom" | "lab" | "seminar_hall" | "office";

export interface Building {
  id: number;
  name: string;
  description: string | null;
  image_url: string | null;
  lat: number;
  lng: number;
}

export interface Department {
  id: number;
  name: string;
  building_id: number;
}

export interface Room {
  id: number;
  name: string;
  type: RoomType;
  floor: number;
  building_id: number;
}

export interface Checkpoint {
  id: number;
  label: string;
  lat: number;
  lng: number;
  building_id: number | null;
  qr_code_id: number | null;
}

export interface Edge {
  id: number;
  checkpoint_a_id: number;
  checkpoint_b_id: number;
  distance_meters: number;
  walking_time_estimate_sec: number;
  is_indoor: boolean;
}
