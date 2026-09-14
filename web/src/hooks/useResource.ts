import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { mockCreate, mockList, mockRemove, mockUpdate } from "../lib/mockData";

/**
 * Generic CRUD hooks for a REST collection at `/{resource}`.
 *
 * TEMPORARY: backend DB (Supabase) is unreachable. These read/write an
 * in-memory mock store (lib/mockData.ts) instead of calling the real API.
 * Remove the mock* imports above and restore the commented api.* calls
 * below once the backend is back up.
 */
export function useList<T>(resource: string) {
  return useQuery({
    queryKey: [resource],
    queryFn: async () => {
      // const { data } = await api.get<T[]>(`/${resource}`);
      return mockList<T>(resource);
    },
  });
}

export function useCreate<T, TInput>(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: TInput) => {
      // const { data } = await api.post<T>(`/${resource}`, input);
      return mockCreate<T & { id: number }>(
        resource,
        input as Record<string, unknown>,
      );
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}

export function useUpdate<T, TInput>(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, input }: { id: number; input: TInput }) => {
      // const { data } = await api.patch<T>(`/${resource}/${id}`, input);
      return mockUpdate<T & { id: number }>(
        resource,
        id,
        input as Record<string, unknown>,
      );
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}

export function useRemove(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: number) => {
      // await api.delete(`/${resource}/${id}`);
      mockRemove(resource, id);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}
