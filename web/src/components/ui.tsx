import type { ButtonHTMLAttributes, ReactNode } from "react";

export function PageHeader({
  title,
  action,
}: {
  title: string;
  action?: ReactNode;
}) {
  return (
    <header className="flex items-center justify-between border-b border-slate-800 px-6 py-4">
      <h1 className="font-heading text-xl font-semibold tracking-tight">
        {title}
      </h1>
      {action}
    </header>
  );
}

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "ghost" | "danger";
}) {
  const styles = {
    primary: "bg-accent text-primary hover:bg-accent/90",
    ghost:
      "border border-slate-700 text-slate-300 hover:border-slate-500 hover:text-foreground",
    danger: "text-destructive hover:bg-destructive/10",
  }[variant];
  return (
    <button
      className={`cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${styles} ${className}`}
      {...props}
    />
  );
}

export function Field({
  label,
  children,
  error,
}: {
  label: string;
  children: ReactNode;
  error?: string;
}) {
  return (
    <label className="flex flex-col gap-1.5 text-sm">
      <span className="font-medium text-slate-300">{label}</span>
      {children}
      {error && (
        <span role="alert" className="text-xs text-destructive">
          {error}
        </span>
      )}
    </label>
  );
}

export const inputClass =
  "rounded-md border border-slate-700 bg-background px-3 py-2 text-sm outline-none focus:border-accent focus:ring-1 focus:ring-accent";
