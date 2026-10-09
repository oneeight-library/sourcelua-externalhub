import * as React from "react";
import { CheckCircle2, AlertCircle, AlertTriangle, Info, X } from "lucide-react";
import { cn } from "@/lib/utils.js";

const ToastContext = React.createContext(null);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = React.useState([]);

  const removeToast = React.useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const addToast = React.useCallback(({ title, description, variant = "default", duration = 4500 }) => {
    const id = Math.random().toString(36).substring(2, 9);
    setToasts((prev) => [...prev, { id, title, description, variant, duration }]);

    if (duration > 0) {
      setTimeout(() => {
        removeToast(id);
      }, duration);
    }
  }, [removeToast]);

  const toast = React.useMemo(() => {
    const fn = (opts) => addToast(opts);
    fn.success = (title, description, duration) => addToast({ title, description, variant: "success", duration });
    fn.error = (title, description, duration) => addToast({ title, description, variant: "destructive", duration });
    fn.warn = (title, description, duration) => addToast({ title, description, variant: "warning", duration });
    fn.info = (title, description, duration) => addToast({ title, description, variant: "info", duration });
    return fn;
  }, [addToast]);

  return (
    <ToastContext.Provider value={{ toast, removeToast }}>
      {children}
      <ToastViewport toasts={toasts} onDismiss={removeToast} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = React.useContext(ToastContext);
  if (!ctx) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return ctx;
}

function ToastViewport({ toasts, onDismiss }) {
  if (toasts.length === 0) return null;

  return (
    <div className="fixed top-4 right-4 z-[9999] flex flex-col gap-2.5 max-w-sm w-full pointer-events-none px-3 sm:px-0">
      {toasts.map((t) => (
        <ToastItem key={t.id} toast={t} onDismiss={() => onDismiss(t.id)} />
      ))}
    </div>
  );
}

function ToastItem({ toast, onDismiss }) {
  const icons = {
    success: <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />,
    destructive: <AlertCircle className="h-4 w-4 text-rose-400 shrink-0 mt-0.5" />,
    warning: <AlertTriangle className="h-4 w-4 text-amber-400 shrink-0 mt-0.5" />,
    info: <Info className="h-4 w-4 text-cyan-400 shrink-0 mt-0.5" />,
    default: <Info className="h-4 w-4 text-indigo-400 shrink-0 mt-0.5" />
  };

  const borders = {
    success: "border-emerald-500/30 bg-gradient-to-r from-emerald-950/70 via-zinc-950/95 to-zinc-950/95 shadow-emerald-950/30",
    destructive: "border-rose-500/30 bg-gradient-to-r from-rose-950/70 via-zinc-950/95 to-zinc-950/95 shadow-rose-950/30",
    warning: "border-amber-500/30 bg-gradient-to-r from-amber-950/70 via-zinc-950/95 to-zinc-950/95 shadow-amber-950/30",
    info: "border-cyan-500/30 bg-gradient-to-r from-cyan-950/70 via-zinc-950/95 to-zinc-950/95 shadow-cyan-950/30",
    default: "border-zinc-800 bg-zinc-950/95 shadow-black/50"
  };

  return (
    <div
      className={cn(
        "pointer-events-auto flex items-start gap-3 p-3.5 rounded-2xl border backdrop-blur-xl shadow-2xl transition-all duration-300 animate-in slide-in-from-top-3 sm:slide-in-from-right-4 fade-in-50",
        borders[toast.variant] || borders.default
      )}
    >
      {icons[toast.variant] || icons.default}

      <div className="flex-1 min-w-0 pr-1">
        {toast.title && (
          <h5 className="text-xs font-bold text-zinc-100 tracking-tight leading-snug truncate">
            {toast.title}
          </h5>
        )}
        {toast.description && (
          <p className="text-[11px] text-zinc-400 mt-0.5 leading-relaxed break-words font-medium">
            {toast.description}
          </p>
        )}
      </div>

      <button
        type="button"
        onClick={onDismiss}
        className="text-zinc-500 hover:text-zinc-300 transition-colors p-1 rounded-lg hover:bg-zinc-800/60 shrink-0"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}
