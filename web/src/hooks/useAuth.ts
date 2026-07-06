import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { useAuthStore } from "../stores/auth";
import type { TokenPair, User } from "../lib/types";

interface LoginArgs {
  email: string;
  password: string;
}

export function useLogin() {
  const setTokens = useAuthStore((s) => s.setTokens);
  return useMutation({
    mutationFn: async ({ email, password }: LoginArgs) => {
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
      const { data } = await api.get<User>("/auth/me");
      setUser(data);
      return data;
    },
  });
}
