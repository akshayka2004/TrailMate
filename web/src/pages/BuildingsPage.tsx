import { useState } from "react";
import { Modal } from "../components/Modal";
import { Button, Field, PageHeader, inputClass } from "../components/ui";
import {
  useCreate,
  useList,
  useRemove,
  useUpdate,
} from "../hooks/useResource";
import type { Building } from "../lib/resourceTypes";

interface FormState {
  name: string;
  description: string;
  lat: string;
  lng: string;
}

const empty: FormState = { name: "", description: "", lat: "", lng: "" };

export function BuildingsPage() {
  const { data: buildings, isLoading } = useList<Building>("buildings");
  const create = useCreate<Building, unknown>("buildings");
  const update = useUpdate<Building, unknown>("buildings");
  const remove = useRemove("buildings");

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Building | null>(null);
  const [form, setForm] = useState<FormState>(empty);
  const [error, setError] = useState<string | null>(null);

  function openCreate() {
    setEditing(null);
    setForm(empty);
    setError(null);
    setOpen(true);
  }

  function openEdit(b: Building) {
    setEditing(b);
    setForm({
      name: b.name,
      description: b.description ?? "",
      lat: String(b.lat),
      lng: String(b.lng),
    });
    setError(null);
    setOpen(true);
  }

  async function submit() {
    setError(null);
    const payload = {
      name: form.name.trim(),
      description: form.description.trim() || null,
      lat: Number(form.lat),
      lng: Number(form.lng),
    };
    if (!payload.name || Number.isNaN(payload.lat) || Number.isNaN(payload.lng)) {
      setError("Name, latitude and longitude are required.");
      return;
    }
    try {
      if (editing) await update.mutateAsync({ id: editing.id, input: payload });
      else await create.mutateAsync(payload);
      setOpen(false);
    } catch {
      setError("Save failed — name may already exist.");
    }
  }

  async function onDelete(b: Building) {
    if (!confirm(`Delete building "${b.name}"?`)) return;
    try {
      await remove.mutateAsync(b.id);
    } catch {
      alert("Cannot delete: building still has checkpoints or you lack permission.");
    }
  }

  return (
    <>
      <PageHeader
        title="Buildings"
        action={<Button onClick={openCreate}>New building</Button>}
      />
      <div className="p-6">
        {isLoading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : (
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-slate-800 text-left text-slate-400">
                <th className="py-2 font-medium">Name</th>
                <th className="py-2 font-medium">Coordinates</th>
                <th className="py-2 font-medium">Description</th>
                <th className="py-2" />
              </tr>
            </thead>
            <tbody>
              {buildings?.map((b) => (
                <tr key={b.id} className="border-b border-slate-800/60">
                  <td className="py-2 font-medium">{b.name}</td>
                  <td className="py-2 tabular-nums text-slate-400">
                    {b.lat.toFixed(4)}, {b.lng.toFixed(4)}
                  </td>
                  <td className="py-2 text-slate-400">{b.description ?? "—"}</td>
                  <td className="py-2 text-right">
                    <Button variant="ghost" onClick={() => openEdit(b)}>
                      Edit
                    </Button>{" "}
                    <Button variant="danger" onClick={() => onDelete(b)}>
                      Delete
                    </Button>
                  </td>
                </tr>
              ))}
              {buildings?.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-6 text-center text-slate-500">
                    No buildings yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {open && (
        <Modal
          title={editing ? "Edit building" : "New building"}
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
            <Field label="Description">
              <input
                className={inputClass}
                value={form.description}
                onChange={(e) =>
                  setForm({ ...form, description: e.target.value })
                }
              />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Latitude">
                <input
                  className={inputClass}
                  value={form.lat}
                  onChange={(e) => setForm({ ...form, lat: e.target.value })}
                />
              </Field>
              <Field label="Longitude">
                <input
                  className={inputClass}
                  value={form.lng}
                  onChange={(e) => setForm({ ...form, lng: e.target.value })}
                />
              </Field>
            </div>
            {error && (
              <p role="alert" className="text-xs text-destructive">
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button
                onClick={submit}
                disabled={create.isPending || update.isPending}
              >
                Save
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
