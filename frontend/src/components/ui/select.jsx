import * as React from "react";
import { createPortal } from "react-dom";
import { Check, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils.js";

const SelectContext = React.createContext(null);

export function Select({ value, onValueChange, children }) {
  const [isOpen, setIsOpen] = React.useState(false);
  const [coords, setCoords] = React.useState({ top: 0, left: 0, width: 0 });
  const triggerRef = React.useRef(null);
  const containerRef = React.useRef(null);

  const updateCoords = () => {
    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect();
      setCoords({
        top: rect.bottom + window.scrollY + 4,
        left: rect.left + window.scrollX,
        width: rect.width
      });
    }
  };

  React.useEffect(() => {
    if (isOpen) {
      updateCoords();
      window.addEventListener("resize", updateCoords);
      window.addEventListener("scroll", updateCoords, true);
    }
    return () => {
      window.removeEventListener("resize", updateCoords);
      window.removeEventListener("scroll", updateCoords, true);
    };
  }, [isOpen]);

  React.useEffect(() => {
    const handleOutsideClick = (event) => {
      if (
        containerRef.current && !containerRef.current.contains(event.target) &&
        !event.target.closest('[data-select-content]')
      ) {
        setIsOpen(false);
      }
    };
    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    };
    if (isOpen) {
      document.addEventListener("mousedown", handleOutsideClick);
      document.addEventListener("keydown", handleKeyDown);
    }
    return () => {
      document.removeEventListener("mousedown", handleOutsideClick);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isOpen]);

  return (
    <SelectContext.Provider value={{ value, onValueChange, isOpen, setIsOpen, triggerRef, coords }}>
      <div ref={containerRef} className="relative inline-block w-full">
        {children}
      </div>
    </SelectContext.Provider>
  );
}

export function SelectTrigger({ className, children, ...props }) {
  const { isOpen, setIsOpen, triggerRef } = React.useContext(SelectContext);

  return (
    <button
      ref={triggerRef}
      type="button"
      onClick={() => setIsOpen(!isOpen)}
      className={cn(
        "flex h-9 w-full items-center justify-between rounded-lg border border-zinc-800 bg-zinc-900/90 px-3 py-2 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors shadow-sm",
        isOpen && "border-zinc-700 ring-1 ring-zinc-700",
        className
      )}
      {...props}
    >
      {children}
      <ChevronDown className={cn("h-3.5 w-3.5 text-zinc-400 transition-transform duration-200", isOpen && "rotate-180")} />
    </button>
  );
}

export function SelectValue({ placeholder }) {
  const { value } = React.useContext(SelectContext);
  return (
    <span className="truncate">
      {value || <span className="text-zinc-500">{placeholder}</span>}
    </span>
  );
}

export function SelectContent({ className, children, ...props }) {
  const { isOpen, coords } = React.useContext(SelectContext);

  if (!isOpen) return null;

  return createPortal(
    <div
      data-select-content="true"
      style={{
        position: "absolute",
        top: `${coords.top}px`,
        left: `${coords.left}px`,
        width: `${coords.width}px`,
      }}
      className={cn(
        "z-[9999] max-h-60 overflow-y-auto rounded-xl border border-zinc-800 bg-zinc-950/98 backdrop-blur-md p-1.5 text-zinc-100 shadow-2xl animate-in fade-in-0 zoom-in-95",
        className
      )}
      {...props}
    >
      {children}
    </div>,
    document.body
  );
}

export function SelectItem({ value, children, className, ...props }) {
  const { value: selectedValue, onValueChange, setIsOpen } = React.useContext(SelectContext);
  const isSelected = selectedValue === value;

  const handleSelect = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (onValueChange) onValueChange(value);
    setIsOpen(false);
  };

  return (
    <div
      onClick={handleSelect}
      className={cn(
        "relative flex w-full cursor-pointer select-none items-center justify-between rounded-lg px-2.5 py-1.5 text-xs text-zinc-300 outline-none transition-colors hover:bg-zinc-800/90 hover:text-zinc-100",
        isSelected && "bg-zinc-800/60 font-semibold text-emerald-400",
        className
      )}
      {...props}
    >
      <span>{children}</span>
      {isSelected && <Check className="h-3.5 w-3.5 text-emerald-400 shrink-0 ml-2" />}
    </div>
  );
}
