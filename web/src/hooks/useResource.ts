import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseQueryOptions,
} from "@tanstack/react-query";
import { api } from "../lib/api";

/**
 * Generic CRUD hooks for a REST collection at `/{resource}`.
 *
 * `options.refetchInterval` lets a specific page poll for changes made from
 * elsewhere (e.g. the student /find page polling while an admin on a
 * different device/browser is adding checkpoints) — admin pages don't pass
 * this, so they stay plain fetch-on-mount/on-invalidate.
 */
export function useList<T>(
  resource: string,
  options?: Pick<UseQueryOptions<T[]>, "refetchInterval">,
) {
  return useQuery({
    queryKey: [resource],
    queryFn: async () => {
      const { data } = await api.get<T[]>(`/${resource}`);
      return data;
    },
    ...options,
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
