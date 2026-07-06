import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AppLayout } from "./components/AppLayout";
import { ProtectedRoute } from "./components/ProtectedRoute";
import { BuildingsPage } from "./pages/BuildingsPage";
import { CheckpointsPage } from "./pages/CheckpointsPage";
import { DepartmentsPage } from "./pages/DepartmentsPage";
import { GraphPage } from "./pages/GraphPage";
import { LoginPage } from "./pages/LoginPage";
import { RoomsPage } from "./pages/RoomsPage";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false } },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }
          >
            <Route path="/" element={<Navigate to="/buildings" replace />} />
            <Route path="/buildings" element={<BuildingsPage />} />
            <Route path="/departments" element={<DepartmentsPage />} />
            <Route path="/rooms" element={<RoomsPage />} />
            <Route path="/checkpoints" element={<CheckpointsPage />} />
            <Route path="/graph" element={<GraphPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}

export default App;
