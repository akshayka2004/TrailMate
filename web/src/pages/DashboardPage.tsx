import { useNavigate } from "react-router-dom";
import { useAuthStore } from "../stores/auth";

export function DashboardPage() {
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);

  return (
    <main className="min-h-dvh bg-background text-foreground">
      <header className="flex items-center justify-between border-b border-slate-800 px-6 py-4">
        <h1 className="font-heading text-lg font-semibold tracking-tight">
          TrailMate Admin
        </h1>
        <button
          type="button"
          onClick={() => {
            logout();
            navigate("/login", { replace: true });
          }}
          className="cursor-pointer rounded-md border border-slate-700 px-3 py-1.5 text-sm text-slate-300 transition-colors hover:border-slate-500 hover:text-foreground"
        >
          Sign out
        </button>
      </header>

      <section className="p-6">
        <p className="text-sm text-slate-400">Signed in as</p>
        <p className="mt-1 text-lg font-medium">{user?.name}</p>
        <p className="text-sm text-slate-400">{user?.email}</p>
        <span className="mt-3 inline-block rounded-full bg-accent/15 px-3 py-1 text-xs font-medium text-accent">
          {user?.role}
        </span>
        <p className="mt-8 text-sm text-slate-500">
          Phase 2 complete. Admin CRUD screens land in Phase 3.
        </p>
      </section>
    </main>
  );
}
