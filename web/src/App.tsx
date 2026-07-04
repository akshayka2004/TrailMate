function App() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-3 bg-background text-foreground">
      <h1 className="font-heading text-4xl font-semibold tracking-tight">
        TrailMate
      </h1>
      <p className="text-sm text-slate-400">
        Admin portal scaffold — Phase 0. Tailwind is working if this page is
        dark with a green dot below.
      </p>
      <span
        className="h-3 w-3 rounded-full bg-accent"
        aria-label="Tailwind status indicator"
      />
    </main>
  );
}

export default App;
