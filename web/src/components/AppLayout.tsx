import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuthStore } from "../stores/auth";

const NAV = [
  { to: "/buildings", label: "Buildings" },
  { to: "/departments", label: "Departments" },
  { to: "/rooms", label: "Rooms" },
  { to: "/checkpoints", label: "Checkpoints" },
  { to: "/graph", label: "Route graph" },
];

export function AppLayout() {
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);

  return (
    <div className="flex min-h-dvh bg-background text-foreground">
      <aside className="flex w-56 flex-col border-r border-slate-800 bg-secondary/40">
        <div className="px-5 py-4">
          <p className="font-heading text-lg font-semibold tracking-tight">
            TrailMate
          </p>
          <p className="text-xs text-slate-500">Admin portal</p>
        </div>
        <nav className="flex flex-1 flex-col gap-1 px-3">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-accent/15 text-accent"
                    : "text-slate-400 hover:bg-slate-800 hover:text-foreground"
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-slate-800 px-4 py-3">
          <p className="truncate text-xs text-slate-400">{user?.email}</p>
          <span className="text-xs text-accent">{user?.role}</span>
          <button
            type="button"
            onClick={() => {
              logout();
              navigate("/login", { replace: true });
            }}
            className="mt-2 block cursor-pointer text-xs text-slate-500 hover:text-foreground"
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
