import { useQueryClient } from "@tanstack/react-query";
import { useMemo } from "react";
import ReactFlow, {
  Background,
  Controls,
  type Connection,
  type Edge as FlowEdge,
  type Node as FlowNode,
} from "reactflow";
import "reactflow/dist/style.css";
import { PageHeader } from "../components/ui";
import { useCreate, useList, useRemove } from "../hooks/useResource";
import type { Checkpoint, Edge } from "../lib/resourceTypes";

const WALK_SPEED_M_PER_S = 1.4;

// Haversine distance in metres between two lat/lng points.
function haversine(a: Checkpoint, b: Checkpoint): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

const PROJECTION_SCALE = 100000;

export function GraphPage() {
  const { data: checkpoints } = useList<Checkpoint>("checkpoints");
  const { data: edges } = useList<Edge>("edges");
  const createEdge = useCreate<Edge, unknown>("edges");
  const removeEdge = useRemove("edges");
  const qc = useQueryClient();

  const cpById = useMemo(
    () => new Map(checkpoints?.map((c) => [c.id, c])),
    [checkpoints],
  );

  const nodes: FlowNode[] = useMemo(() => {
    if (!checkpoints?.length) return [];
    const maxLat = Math.max(...checkpoints.map((c) => c.lat));
    const minLng = Math.min(...checkpoints.map((c) => c.lng));
    return checkpoints.map((c) => {
      // Longitude -> x; latitude -> y inverted so north renders at the top.
      const x = (c.lng - minLng) * PROJECTION_SCALE;
      const y = (maxLat - c.lat) * PROJECTION_SCALE;
      return {
        id: String(c.id),
        position: { x, y },
        data: { label: c.label },
        style: {
          background: c.building_id ? "#1e293b" : "#0f172a",
          color: "#f8fafc",
          border: "1px solid #334155",
          borderRadius: 8,
          fontSize: 11,
          padding: 6,
          width: 130,
        },
      };
    });
  }, [checkpoints]);

  const flowEdges: FlowEdge[] = useMemo(
    () =>
      edges?.map((e) => ({
        id: String(e.id),
        source: String(e.checkpoint_a_id),
        target: String(e.checkpoint_b_id),
        label: `${Math.round(e.distance_meters)}m`,
        animated: !e.is_indoor,
        style: { stroke: e.is_indoor ? "#22c55e" : "#64748b" },
        labelStyle: { fill: "#94a3b8", fontSize: 10 },
      })) ?? [],
    [edges],
  );

  async function onConnect(conn: Connection) {
    if (!conn.source || !conn.target || conn.source === conn.target) return;
    const a = cpById.get(Number(conn.source));
    const b = cpById.get(Number(conn.target));
    if (!a || !b) return;
    const dist = haversine(a, b);
    try {
      await createEdge.mutateAsync({
        checkpoint_a_id: a.id,
        checkpoint_b_id: b.id,
        distance_meters: Math.round(dist * 10) / 10,
        walking_time_estimate_sec: Math.max(1, Math.round(dist / WALK_SPEED_M_PER_S)),
        is_indoor: Boolean(a.building_id && b.building_id),
      });
    } catch {
      alert("Edge already exists or is invalid.");
    }
  }

  async function onEdgesDelete(deleted: FlowEdge[]) {
    for (const e of deleted) await removeEdge.mutateAsync(Number(e.id));
    qc.invalidateQueries({ queryKey: ["edges"] });
  }

  return (
    <>
      <PageHeader title="Route graph" />
      <div className="p-6">
        <p className="mb-3 text-xs text-slate-500">
          Drag from one checkpoint handle to another to connect them — distance
          and walking time are computed automatically. Select an edge and press
          Delete/Backspace to remove it. Green edges are indoor.
        </p>
        <div className="h-[72vh] overflow-hidden rounded-xl border border-slate-800">
          <ReactFlow
            nodes={nodes}
            edges={flowEdges}
            onConnect={onConnect}
            onEdgesDelete={onEdgesDelete}
            fitView
          >
            <Background color="#1e293b" />
            <Controls />
          </ReactFlow>
        </div>
      </div>
    </>
  );
}
