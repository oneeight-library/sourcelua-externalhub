import { clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

export function formatRupiah(num) {
  if (num === null || num === undefined || isNaN(num)) return "Rp 0";
  return "Rp " + Math.floor(num).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}
