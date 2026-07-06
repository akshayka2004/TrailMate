import { useState } from "react";
import { Modal } from "../components/Modal";
import { Button, Field, PageHeader, inputClass } from "../components/ui";
import {
  useCreate,
  useList,
  useRemove,
  useUpdate,
} from "../hooks/useResource";
import type { Building, Department } from "../lib/resourceTypes";

export function DepartmentsPage() {
  const { data: departments, isLoading } = useList<Department>("departments");
  const { data: buildings } = useList<Building>("buildings");
  const create = useCreate<Department, unknown>("departments");
  const update = useUpdate<Department, unknown>("departments");
  const remove = useRemove("departments");

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Department | null>(null);
  const [name, setName] = useState("");
  const [buildingId, setBuildingId] = useState<string>("");
  const [error, setError] = useState<string | null>(null);

  const buildingName = (id: number) =>
    buildings?.find((b) => b.id === id)?.name ?? `#${id}`;

  function openCreate() {
    setEditing(null);
    setName("");
    setBuildingId(buildings?.[0] ? String(buildings[0].id) : "");
    setError(null);
    setOpen(true);
  }

  function openEdit(d: Department) {
    setEditing(d);
    setName(d.name);
    setBuildingId(String(d.building_id));
    setError(null);
    setOpen(true);
  }

  async function submit() {
    if (!name.trim() || !buildingId) {
      setError("Name and building are required.");
      return;
    }
    const payload = { name: name.trim(), building_id: Number(buildingId) };
    try {
      if (editing) await update.mutateAsync({ id: editing.id, input: payload });
      else await create.mutateAsync(payload);
      setOpen(false);
    } catch {
      setError("Save failed.");
    }
  }

  async function onDelete(d: Department) {
    if (!confirm(`Delete department "${d.name}"?`)) return;
    try {
      await remove.mutateAsync(d.id);
    } catch {
      alert("Delete failed — admin role required.");
    }
  }

  return (
    <>
      <PageHeader
        title="Departments"
        action={
          <Button onClick={openCreate} disabled={!buildings?.length}>
            New department
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
                <th className="py-2 font-medium">Building</th>
                <th className="py-2" />
              </tr>
            </thead>
            <tbody>
              {departments?.map((d) => (
                <tr key={d.id} className="border-b border-slate-800/60">
                  <td className="py-2 font-medium">{d.name}</td>
                  <td className="py-2 text-slate-400">
                    {buildingName(d.building_id)}
                  </td>
                  <td className="py-2 text-right">
                    <Button variant="ghost" onClick={() => openEdit(d)}>
                      Edit
                    </Button>{" "}
                    <Button variant="danger" onClick={() => onDelete(d)}>
                      Delete
                    </Button>
                  </td>
                </tr>
              ))}
              {departments?.length === 0 && (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-slate-500">
                    No departments yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {open && (
        <Modal
          title={editing ? "Edit department" : "New department"}
          onClose={() => setOpen(false)}
        >
          <div className="flex flex-col gap-4">
            <Field label="Name">
              <input
                className={inputClass}
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </Field>
            <Field label="Building">
              <select
                className={inputClass}
                value={buildingId}
                onChange={(e) => setBuildingId(e.target.value)}
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
