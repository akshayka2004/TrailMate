import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useMe } from "../hooks/useAuth";
import { useAuthStore } from "../stores/auth";

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const accessToken = useAuthStore((s) => s.accessToken);
  const { isLoading, isError } = useMe(Boolean(accessToken));

  if (!accessToken) return <Navigate to="/login" replace />;
  if (isLoading) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-background text-slate-400">
        Loading…
      </div>
    );
  }
  if (isError) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
