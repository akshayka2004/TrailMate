import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { useAuthStore } from "../stores/auth";
import type { TokenPair, User } from "../lib/types";

interface LoginArgs {
  email: string;
  password: string;
}

// TEMPORARY: backend DB (Supabase) is unreachable. Hardcode the seeded admin
// credentials so the web UI is demoable without a live API. Remove this
// block and restore the plain api.post/api.get calls once the backend is
// back up.
const DEMO_EMAIL = "admin@trailmate.dev";
const DEMO_PASSWORD = "Admin@123";
const DEMO_TOKEN = "demo-local-token";
const DEMO_USER: User = {
  id: 1,
  name: "TrailMate Admin",
  email: DEMO_EMAIL,
  role: "admin",
  created_at: new Date().toISOString(),
};

export function useLogin() {
  const setTokens = useAuthStore((s) => s.setTokens);
  return useMutation({
    mutationFn: async ({ email, password }: LoginArgs) => {
      if (email === DEMO_EMAIL && password === DEMO_PASSWORD) {
        const demo: TokenPair = {
          access_token: DEMO_TOKEN,
          refresh_token: DEMO_TOKEN,
          token_type: "bearer",
        };
        return demo;
      }
      // OAuth2 password flow expects form-encoded username/password.
      const form = new URLSearchParams();
      form.append("username", email);
      form.append("password", password);
      const { data } = await api.post<TokenPair>("/auth/login", form, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      });
      return data;
    },
    onSuccess: (data) => setTokens(data.access_token, data.refresh_token),
  });
}

export function useMe(enabled: boolean) {
  const setUser = useAuthStore((s) => s.setUser);
  return useQuery({
    queryKey: ["me"],
    enabled,
    queryFn: async () => {
      const token = useAuthStore.getState().accessToken;
      if (token === DEMO_TOKEN) {
        setUser(DEMO_USER);
        return DEMO_USER;
      }
      const { data } = await api.get<User>("/auth/me");
      setUser(data);
      return data;
    },
  });
}
