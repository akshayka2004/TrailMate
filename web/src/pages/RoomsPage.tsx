import { useState } from "react";
import { Modal } from "../components/Modal";
import { Button, Field, PageHeader, inputClass } from "../components/ui";
import {
  useCreate,
  useList,
  useRemove,
  useUpdate,
} from "../hooks/useResource";
import type { Building, Room, RoomType } from "../lib/resourceTypes";

const ROOM_TYPES: RoomType[] = ["classroom", "lab", "seminar_hall", "office"];

interface FormState {
  name: string;
  type: RoomType;
  floor: string;
  building_id: string;
}

export function RoomsPage() {
  const { data: rooms, isLoading } = useList<Room>("rooms");
  const { data: buildings } = useList<Building>("buildings");
  const create = useCreate<Room, unknown>("rooms");
  const update = useUpdate<Room, unknown>("rooms");
  const remove = useRemove("rooms");

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Room | null>(null);
  const [form, setForm] = useState<FormState>({
    name: "",
    type: "classroom",
    floor: "1",
    building_id: "",
  });
  const [error, setError] = useState<string | null>(null);

  const buildingName = (id: number) =>
    buildings?.find((b) => b.id === id)?.name ?? `#${id}`;

  function openCreate() {
    setEditing(null);
    setForm({
      name: "",
      type: "classroom",
      floor: "1",
      building_id: buildings?.[0] ? String(buildings[0].id) : "",
    });
    setError(null);
    setOpen(true);
  }

  function openEdit(r: Room) {
    setEditing(r);
    setForm({
      name: r.name,
      type: r.type,
      floor: String(r.floor),
      building_id: String(r.building_id),
    });
    setError(null);
    setOpen(true);
  }

  async function submit() {
    if (!form.name.trim() || !form.building_id) {
      setError("Name and building are required.");
      return;
    }
    const payload = {
      name: form.name.trim(),
      type: form.type,
      floor: Number(form.floor),
      building_id: Number(form.building_id),
    };
    try {
      if (editing) await update.mutateAsync({ id: editing.id, input: payload });
      else await create.mutateAsync(payload);
      setOpen(false);
    } catch {
      setError("Save failed.");
    }
  }

  async function onDelete(r: Room) {
    if (!confirm(`Delete room "${r.name}"?`)) return;
    try {
      await remove.mutateAsync(r.id);
    } catch {
      alert("Delete failed — admin role required.");
    }
  }

  return (
    <>
      <PageHeader
        title="Rooms"
        action={
          <Button onClick={openCreate} disabled={!buildings?.length}>
            New room
          </Button>
        }
      />
      <div className="p-6">
        {isLoading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : (
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-slate-800 text-left text-slate-400">
                <th className="py-2 font-medium">Name</th>
                <th className="py-2 font-medium">Type</th>
                <th className="py-2 font-medium">Floor</th>
                <th className="py-2 font-medium">Building</th>
                <th className="py-2" />
              </tr>
            </thead>
            <tbody>
              {rooms?.map((r) => (
                <tr key={r.id} className="border-b border-slate-800/60">
                  <td className="py-2 font-medium">{r.name}</td>
                  <td className="py-2 text-slate-400">
                    {r.type.replace("_", " ")}
                  </td>
                  <td className="py-2 tabular-nums text-slate-400">{r.floor}</td>
                  <td className="py-2 text-slate-400">
                    {buildingName(r.building_id)}
                  </td>
                  <td className="py-2 text-right">
                    <Button variant="ghost" onClick={() => openEdit(r)}>
                      Edit
                    </Button>{" "}
                    <Button variant="danger" onClick={() => onDelete(r)}>
                      Delete
                    </Button>
                  </td>
                </tr>
              ))}
              {rooms?.length === 0 && (
                <tr>
                  <td colSpan={5} className="py-6 text-center text-slate-500">
                    No rooms yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {open && (
        <Modal
          title={editing ? "Edit room" : "New room"}
          onClose={() => setOpen(false)}
        >
          <div className="flex flex-col gap-4">
            <Field label="Name">
              <input
                className={inputClass}
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Type">
                <select
                  className={inputClass}
                  value={form.type}
                  onChange={(e) =>
                    setForm({ ...form, type: e.target.value as RoomType })
                  }
                >
                  {ROOM_TYPES.map((t) => (
                    <option key={t} value={t}>
                      {t.replace("_", " ")}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Floor">
                <input
                  className={inputClass}
                  type="number"
                  value={form.floor}
                  onChange={(e) => setForm({ ...form, floor: e.target.value })}
                />
              </Field>
            </div>
            <Field label="Building">
              <select
                className={inputClass}
                value={form.building_id}
                onChange={(e) =>
                  setForm({ ...form, building_id: e.target.value })
                }
              >
                {buildings?.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </Field>
            {error && (
              <p role="alert" className="text-xs text-destructive">
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button onClick={submit}>Save</Button>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
