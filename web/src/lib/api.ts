import axios, {
  AxiosError,
  type InternalAxiosRequestConfig,
} from "axios";
import { useAuthStore } from "../stores/auth";
import type { TokenPair } from "./types";

const baseURL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";

export const api = axios.create({ baseURL });

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Single-flight refresh: concurrent 401s share one refresh call.
let refreshPromise: Promise<string> | null = null;

async function refreshAccessToken(): Promise<string> {
  const { refreshToken, setTokens, logout } = useAuthStore.getState();
  if (!refreshToken) throw new Error("No refresh token");
  try {
    const { data } = await axios.post<TokenPair>(
      `${baseURL}/auth/refresh`,
      { refresh_token: refreshToken },
    );
    setTokens(data.access_token, data.refresh_token);
    return data.access_token;
  } catch (err) {
    logout();
    throw err;
  }
}

api.interceptors.response.use(
  (res) => res,
  async (error: AxiosError) => {
    const original = error.config as InternalAxiosRequestConfig & {
      _retry?: boolean;
    };
    const isRefreshCall = original?.url?.includes("/auth/refresh");
    if (error.response?.status === 401 && !original._retry && !isRefreshCall) {
      original._retry = true;
      try {
        refreshPromise ??= refreshAccessToken();
        const newToken = await refreshPromise;
        refreshPromise = null;
        original.headers.Authorization = `Bearer ${newToken}`;
        return api(original);
      } catch (refreshErr) {
        refreshPromise = null;
        return Promise.reject(refreshErr);
      }
    }
    return Promise.reject(error);
  },
);
