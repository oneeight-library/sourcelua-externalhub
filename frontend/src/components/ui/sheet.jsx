import * as React from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/utils.js";

const SheetContext = React.createContext({ open: false, onOpenChange: () => {} });

export function Sheet({ open, onOpenChange, children }) {
  return (
    <SheetContext.Provider value={{ open, onOpenChange }}>
      {children}
    </SheetContext.Provider>
  );
}

export function SheetTrigger({ asChild, children, className, ...props }) {
  const { onOpenChange } = React.useContext(SheetContext);
  return (
    <span onClick={() => onOpenChange(true)} className={cn("cursor-pointer", className)} {...props}>
      {children}
    </span>
  );
}

export function SheetContent({ side = "bottom", className, children, ...props }) {
  const { open, onOpenChange } = React.useContext(SheetContext);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center">
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-black/80 backdrop-blur-sm transition-opacity animate-in fade-in-0"
        onClick={() => onOpenChange(false)}
      />

      {/* Sheet Modal */}
      <div
        className={cn(
          "relative z-50 w-full max-w-lg bg-zinc-950 border-t border-zinc-800 p-5 rounded-t-2xl max-h-[85vh] overflow-y-auto shadow-2xl animate-in slide-in-from-bottom duration-200",
          className
        )}
        {...props}
      >
        <div className="w-10 h-1 bg-zinc-700/60 rounded-full mx-auto -mt-2 mb-4 cursor-pointer" onClick={() => onOpenChange(false)} />
        {children}
        <button
          type="button"
          onClick={() => onOpenChange(false)}
          className="absolute right-4 top-4 rounded-sm p-1 text-zinc-400 hover:text-zinc-100 transition-colors"
        >
          <X className="h-4 w-4" />
          <span className="sr-only">Close</span>
        </button>
      </div>
    </div>
  );
}

export function SheetHeader({ className, ...props }) {
  return <div className={cn("flex flex-col space-y-1.5 text-left mb-4", className)} {...props} />;
}

export function SheetTitle({ className, ...props }) {
  return <h3 className={cn("text-base font-semibold text-zinc-100", className)} {...props} />;
}

export function SheetDescription({ className, ...props }) {
  return <p className={cn("text-xs text-muted-foreground", className)} {...props} />;
}
