import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { api } from "../lib/api";

/**
 * Generic CRUD hooks for a REST collection at `/{resource}`.
 * The backend returns the full object on create/update.
 */
export function useList<T>(resource: string) {
  return useQuery({
    queryKey: [resource],
    queryFn: async () => {
      const { data } = await api.get<T[]>(`/${resource}`);
      return data;
    },
  });
}

export function useCreate<T, TInput>(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: TInput) => {
      const { data } = await api.post<T>(`/${resource}`, input);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}

export function useUpdate<T, TInput>(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, input }: { id: number; input: TInput }) => {
      const { data } = await api.patch<T>(`/${resource}/${id}`, input);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}

export function useRemove(resource: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: number) => {
      await api.delete(`/${resource}/${id}`);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: [resource] }),
  });
}
