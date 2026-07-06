import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { useNavigate } from "react-router-dom";
import { z } from "zod";
import { useLogin } from "../hooks/useAuth";

const schema = z.object({
  email: z.string().email("Enter a valid email"),
  password: z.string().min(1, "Password is required"),
});

type FormValues = z.infer<typeof schema>;

export function LoginPage() {
  const navigate = useNavigate();
  const login = useLogin();
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = handleSubmit((values) => {
    login.mutate(values, { onSuccess: () => navigate("/", { replace: true }) });
  });

  return (
    <main className="flex min-h-dvh items-center justify-center bg-background px-4 text-foreground">
      <div className="w-full max-w-sm rounded-xl border border-slate-700 bg-secondary/60 p-8 shadow-xl">
        <h1 className="mb-1 font-heading text-2xl font-semibold tracking-tight">
          TrailMate
        </h1>
        <p className="mb-6 text-sm text-slate-400">Admin portal sign in</p>

        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <label htmlFor="email" className="text-sm font-medium text-slate-300">
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="username"
              className="rounded-md border border-slate-700 bg-background px-3 py-2 text-sm outline-none focus:border-accent focus:ring-1 focus:ring-accent"
              {...register("email")}
            />
            {errors.email && (
              <p role="alert" className="text-xs text-destructive">
                {errors.email.message}
              </p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="password"
              className="text-sm font-medium text-slate-300"
            >
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              className="rounded-md border border-slate-700 bg-background px-3 py-2 text-sm outline-none focus:border-accent focus:ring-1 focus:ring-accent"
              {...register("password")}
            />
            {errors.password && (
              <p role="alert" className="text-xs text-destructive">
                {errors.password.message}
              </p>
            )}
          </div>

          {login.isError && (
            <p role="alert" className="text-xs text-destructive">
              Incorrect email or password.
            </p>
          )}

          <button
            type="submit"
            disabled={login.isPending}
            className="mt-2 cursor-pointer rounded-md bg-accent px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-accent/90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {login.isPending ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </main>
  );
}
