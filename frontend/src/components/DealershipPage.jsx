import * as React from "react";
import { Card, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { formatRupiah } from "@/lib/utils.js";
import {
  ArrowLeft,
  Car,
  Search,
  Check,
  AlertCircle,
  Gauge,
  Zap,
  RefreshCw,
  Store,
  X,
  ChevronDown,
  Users
} from "lucide-react";

// Daftar dealer resmi CDID 100% persis sesuai nilai car.Dealership.Value di in-game CarData
const CDID_DEALERS_LIST = [
  "Semua Dealer",
  "77",
  "Bandung",
  "Otnas",
  "Premium",
  "Toyota",
  "Honda",
  "Hyundai",
  "Mitsubishi",
  "MercedesBenz",
  "Suzuki",
  "Daihatsu",
  "KIA",
  "Nissan",
  "Mazda",
  "Lexus",
  "Wuling",
  "Audi",
  "VW",
  "DIR",
  "Chery",
  "Jaecoo",
  "Geely",
  "Shehua",
  "SLM",
  "Komersial"
];

// Pilihan warna resmi CDID (sesuai Preview.Colors: White, Black, Red, Blue, Yellow, Orange, Green, Pink)
const PRESET_COLORS = [
  { name: "White", label: "Putih", hex: "#ffffff" },
  { name: "Black", label: "Hitam", hex: "#18181b" },
  { name: "Red", label: "Merah", hex: "#e11d48" },
  { name: "Blue", label: "Biru", hex: "#2563eb" },
  { name: "Yellow", label: "Kuning", hex: "#eab308" },
  { name: "Orange", label: "Oranye", hex: "#f97316" },
  { name: "Green", label: "Hijau", hex: "#22c55e" },
  { name: "Pink", label: "Pink", hex: "#ec4899" },
];

// Opsi Sort persis sesuai in-game CDID FilterFrame.Sort
const SORT_OPTIONS = [
  { value: "low_to_high", label: "Low to high (Harga Termurah)" },
  { value: "high_to_low", label: "High to low (Harga Termahal)" },
  { value: "new_limited", label: "New & Limited" },
  { value: "speed_desc", label: "Top Speed Tertinggi" },
  { value: "hp_desc", label: "Tenaga Kuda (HP)" },
];

// Opsi Pass persis sesuai in-game CDID FilterFrame.Pass
const PASS_OPTIONS = [
  { value: "all", label: "Semua Pass (All)" },
  { value: "nopass", label: "No Pass (Reguler)" },
  { value: "luxury", label: "Luxury" },
  { value: "rareimport", label: "Rare Import" },
  { value: "retro", label: "Retro" },
  { value: "emergency", label: "Emergency" },
];

function useOutsideClick(ref, handler) {
  React.useEffect(() => {
    const listener = (event) => {
      if (!ref.current || ref.current.contains(event.target)) return;
      handler(event);
    };
    document.addEventListener("mousedown", listener);
    document.addEventListener("touchstart", listener);
    return () => {
      document.removeEventListener("mousedown", listener);
      document.removeEventListener("touchstart", listener);
    };
  }, [ref, handler]);
}

export function DealershipPage({
  initialDealer = "Semua Dealer",
  bots,
  activeBot,
  onSelectBot,
  dealerCatalog,
  onFetchCars,
  onBuyCar,
  onBackToDashboard,
  isEmbedded = false
}) {
  const [selectedDealer, setSelectedDealer] = React.useState(initialDealer);
  const [searchQuery, setSearchQuery] = React.useState("");
  const [sortBy, setSortBy] = React.useState("low_to_high");
  const [selectedPass, setSelectedPass] = React.useState("all");
  const [modalCar, setModalCar] = React.useState(null);
  const [selectedColor, setSelectedColor] = React.useState(PRESET_COLORS[0]);
  const [buyStatus, setBuyStatus] = React.useState(null);
  const [visibleCount, setVisibleCount] = React.useState(36);

  // Dropdown UI Open States (Custom Context Menus - NO default browser select)
  const [isDealerDropdownOpen, setIsDealerDropdownOpen] = React.useState(false);
  const [isAccountDropdownOpen, setIsAccountDropdownOpen] = React.useState(false);
  const [isSortDropdownOpen, setIsSortDropdownOpen] = React.useState(false);
  const [isPassDropdownOpen, setIsPassDropdownOpen] = React.useState(false);

  const dealerDropdownRef = React.useRef(null);
  const accountDropdownRef = React.useRef(null);
  const sortDropdownRef = React.useRef(null);
  const passDropdownRef = React.useRef(null);

  useOutsideClick(dealerDropdownRef, () => setIsDealerDropdownOpen(false));
  useOutsideClick(accountDropdownRef, () => setIsAccountDropdownOpen(false));
  useOutsideClick(sortDropdownRef, () => setIsSortDropdownOpen(false));
  useOutsideClick(passDropdownRef, () => setIsPassDropdownOpen(false));

  const botList = bots ? Array.from(bots.values()) : [];

  // Multi-select akun untuk eksekusi
  const [selectedBotIds, setSelectedBotIds] = React.useState(() => {
    if (activeBot && activeBot.botId) return [activeBot.botId];
    if (botList.length > 0) return [botList[0].botId];
    return [];
  });

  React.useEffect(() => {
    if (selectedBotIds.length === 0 && botList.length > 0) {
      setSelectedBotIds([activeBot?.botId || botList[0].botId]);
    }
  }, [botList, activeBot]);

  const toggleBot = (botId) => {
    setSelectedBotIds((prev) =>
      prev.includes(botId) ? prev.filter((id) => id !== botId) : [...prev, botId]
    );
  };

  const toggleSelectAll = () => {
    if (selectedBotIds.length === botList.length) {
      setSelectedBotIds([]);
    } else {
      setSelectedBotIds(botList.map((b) => b.botId));
    }
  };

  // Reset pagination saat dealer, filter pass, atau search query berganti
  React.useEffect(() => {
    setVisibleCount(36);
  }, [selectedDealer, searchQuery, selectedPass, sortBy]);

  // Sync initialDealer if URL prop changes
  React.useEffect(() => {
    if (initialDealer) {
      setSelectedDealer(initialDealer);
    }
  }, [initialDealer]);

  // Gabungkan daftar dealer: Daftar default + dealer baru apapun yang dikirim bot secara dinamis
  const dealerOptions = React.useMemo(() => {
    const list = [...CDID_DEALERS_LIST];
    const seen = new Set(list.map((d) => d.toLowerCase()));

    if (activeBot?.dealerList && Array.isArray(activeBot.dealerList)) {
      activeBot.dealerList.forEach((raw) => {
        const lower = raw.toLowerCase().trim();
        if (!seen.has(lower) && raw.trim() !== "") {
          seen.add(lower);
          list.push(raw.trim());
        }
      });
    }
    return list;
  }, [activeBot?.dealerList]);

  // Request cars from first selected bot (or activeBot)
  const queryBot = activeBot || (selectedBotIds[0] ? bots?.get(selectedBotIds[0]) : botList[0]);
  const fetchedRef = React.useRef({ botId: null, dealer: null });
  React.useEffect(() => {
    if (queryBot && queryBot.botId) {
      const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
      if (fetchedRef.current.botId === queryBot.botId && fetchedRef.current.dealer === dKey) {
        return;
      }
      fetchedRef.current = { botId: queryBot.botId, dealer: dKey };
      onFetchCars(queryBot.botId, dKey);
    }
  }, [selectedDealer, queryBot?.botId, onFetchCars]);

  const dealerKey = (selectedDealer === "Semua Dealer" ? "all" : selectedDealer).toLowerCase().replace(/\s+/g, "");
  const rawCars = dealerCatalog[dealerKey] || dealerCatalog["all"] || [];

  // PENGELOMPOKAN & FILTER 100% PERSIS SEPERTI IN-GAME CDID DEALERSHIP
  const filteredCars = React.useMemo(() => {
    const selLower = selectedDealer.toLowerCase().trim();
    return rawCars
      .filter((car) => {
        const carDealerLower = (car.dealer || "").toLowerCase().trim();
        const matchesDealer =
          selectedDealer === "Semua Dealer" ||
          carDealerLower === selLower;

        const matchesSearch =
          !searchQuery.trim() ||
          car.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          car.id.toLowerCase().includes(searchQuery.toLowerCase());

        // Filter Pass persis sesuai in-game CDID (FilterFrame.Pass)
        let matchesPass = true;
        if (selectedPass === "nopass") {
          matchesPass = !car.isGamepass && (!car.gamepass || car.gamepass === "None Gamepass");
        } else if (selectedPass === "luxury") {
          matchesPass = !!(car.gamepass && car.gamepass.includes("Luxury"));
        } else if (selectedPass === "rareimport") {
          matchesPass = !!(car.gamepass && car.gamepass.includes("Rare Import"));
        } else if (selectedPass === "retro") {
          matchesPass = !!(car.gamepass && car.gamepass.includes("Retro"));
        } else if (selectedPass === "emergency") {
          matchesPass = !!(car.gamepass && car.gamepass.includes("Emergency"));
        }

        return matchesDealer && matchesSearch && matchesPass;
      })
      .sort((a, b) => {
        // Sort persis sesuai in-game CDID (FilterFrame.Sort)
        if (sortBy === "new_limited") {
          const aPriority = (a.isLimited ? 2 : 0) + (a.isNew ? 1 : 0);
          const bPriority = (b.isLimited ? 2 : 0) + (b.isNew ? 1 : 0);
          if (aPriority !== bPriority) return bPriority - aPriority;
          return a.cost - b.cost;
        }
        if (sortBy === "low_to_high") return a.cost - b.cost;
        if (sortBy === "high_to_low") return b.cost - a.cost;
        if (sortBy === "speed_desc") return (b.topSpeed || 0) - (a.topSpeed || 0);
        if (sortBy === "hp_desc") return (b.hp || 0) - (a.hp || 0);
        return 0;
      });
  }, [rawCars, selectedDealer, searchQuery, sortBy, selectedPass]);

  const displayedCars = React.useMemo(() => {
    return filteredCars.slice(0, visibleCount);
  }, [filteredCars, visibleCount]);

  const handleOpenBuyModal = (car) => {
    setModalCar(car);
    setSelectedColor(PRESET_COLORS[0]);
    setBuyStatus(null);
  };

  const handleConfirmBuy = () => {
    if (!modalCar || selectedBotIds.length === 0) return;
    selectedBotIds.forEach((botId) => {
      onBuyCar(botId, modalCar.id, modalCar.dealer, selectedColor.name);
    });
    setBuyStatus("SUBMITTED");
    setTimeout(() => {
      setBuyStatus("SUCCESS");
      setTimeout(() => {
        setModalCar(null);
        setBuyStatus(null);
      }, 1500);
    }, 800);
  };

  // Helper info trigger akun terpilih
  const selectedBots = botList.filter((b) => selectedBotIds.includes(b.botId));
  const accountTriggerLabel =
    selectedBots.length === 0
      ? "Pilih Akun"
      : selectedBots.length === 1
      ? `${selectedBots[0].name || selectedBots[0].botId} (${formatRupiah(selectedBots[0].currentCash || 0)})`
      : `${selectedBots.length} Akun Terpilih`;

  return (
    <div className={`w-full selection:bg-emerald-500/20 selection:text-emerald-300 ${
      isEmbedded ? "space-y-4" : "h-screen h-[100dvh] overflow-y-auto overflow-x-hidden bg-zinc-950 text-zinc-100 flex flex-col overscroll-contain"
    }`}>
      
      {/* 1. Header Toolbar dengan Dropdown Showroom & Dropdown Multi-Akun */}
      <header className={`w-full ${
        isEmbedded 
          ? "rounded-2xl border border-zinc-800/80 bg-zinc-900/60 backdrop-blur-xl p-2.5 sm:p-3 shadow-md"
          : "sticky top-0 z-40 border-b border-zinc-800/80 bg-zinc-950/90 backdrop-blur-xl"
      }`}>
        <div className={`flex items-center justify-between gap-2 sm:gap-4 ${
          isEmbedded ? "w-full" : "max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 h-14 sm:h-16"
        }`}>
          
          {/* Left: Tombol Kembali & Dropdown Showroom CDID */}
          <div className="flex items-center gap-2 sm:gap-3">
            <Button
              variant="outline"
              size="sm"
              onClick={onBackToDashboard}
              className="h-8 sm:h-9 px-2.5 sm:px-3 gap-1.5 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 hover:text-zinc-100 text-xs font-semibold text-zinc-200 shadow-sm active:scale-95 transition-all"
            >
              <ArrowLeft className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-zinc-400" />
              <span className="hidden xs:inline sm:inline">Dashboard</span>
            </Button>

            <div className="h-4 w-px bg-zinc-800" />

            {/* Dropdown Shadcn UI Style untuk List Showroom CDID */}
            <div className="relative" ref={dealerDropdownRef}>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIsDealerDropdownOpen((prev) => !prev)}
                className="h-8 sm:h-9 px-2.5 sm:px-3 gap-2 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 text-xs font-bold text-zinc-100 shadow-sm transition-all"
              >
                <Store className="h-4 w-4 text-emerald-400 shrink-0" />
                <span className="truncate max-w-[130px] sm:max-w-xs">
                  {selectedDealer === "Semua Dealer" ? "CDID Showroom" : selectedDealer}
                </span>
                <Badge variant="emerald" className="text-[8px] sm:text-[9px] font-mono px-1 sm:px-1.5 py-0 leading-tight hidden xs:inline-flex">
                  Live
                </Badge>
                <ChevronDown className={`h-3.5 w-3.5 text-zinc-400 ml-0.5 shrink-0 transition-transform duration-200 ${isDealerDropdownOpen ? "rotate-180" : ""}`} />
              </Button>

              {isDealerDropdownOpen && (
                <div className="absolute left-0 mt-2 w-56 max-h-80 overflow-y-auto rounded-xl border border-zinc-800 bg-zinc-950/95 backdrop-blur-xl p-1.5 text-zinc-200 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-150">
                  <div className="px-2 py-1.5 text-[10px] font-bold uppercase tracking-wider text-zinc-400">
                    Pilih Showroom CDID
                  </div>
                  <div className="h-px bg-zinc-800/80 my-1" />
                  {dealerOptions.map((dealerName) => {
                    const isSelected = selectedDealer.toLowerCase().trim() === dealerName.toLowerCase().trim();
                    return (
                      <button
                        key={dealerName}
                        type="button"
                        onClick={() => {
                          setSelectedDealer(dealerName);
                          setIsDealerDropdownOpen(false);
                          const cleanKey = dealerName.replace(/\s+/g, "_").toLowerCase();
                          if (typeof window !== "undefined") {
                            window.history.replaceState(
                              null,
                              "",
                              dealerName === "Semua Dealer" ? "/cdid_dealer" : `/cdid_${cleanKey}`
                            );
                          }
                        }}
                        className={`w-full text-left flex items-center justify-between px-2.5 py-1.5 text-xs rounded-lg transition-colors cursor-pointer ${
                          isSelected
                            ? "bg-emerald-500/15 text-emerald-400 font-bold"
                            : "hover:bg-zinc-900 text-zinc-300"
                        }`}
                      >
                        <span>{dealerName}</span>
                        {isSelected && <Check className="h-3.5 w-3.5 text-emerald-400" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Right: Dropdown Multi-Akun Eksekusi (Checkbox Context Menu dengan Nominal Uang) */}
          <div className="flex items-center gap-2">
            <div className="relative" ref={accountDropdownRef}>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIsAccountDropdownOpen((prev) => !prev)}
                className="h-8 sm:h-9 px-2.5 sm:px-3 gap-1.5 sm:gap-2 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 text-xs font-bold text-zinc-200 shadow-sm transition-all"
              >
                <Users className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                <span className="truncate max-w-[130px] sm:max-w-xs font-mono text-[11px] sm:text-xs">
                  {accountTriggerLabel}
                </span>
                <ChevronDown className={`h-3.5 w-3.5 text-zinc-400 shrink-0 transition-transform duration-200 ${isAccountDropdownOpen ? "rotate-180" : ""}`} />
              </Button>

              {isAccountDropdownOpen && (
                <div className="absolute right-0 mt-2 w-64 sm:w-72 max-h-80 overflow-y-auto rounded-xl border border-zinc-800 bg-zinc-950/95 backdrop-blur-xl p-1.5 text-zinc-200 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-150">
                  <div className="flex items-center justify-between px-2 py-1.5">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400">
                      Akun Eksekusi ({selectedBotIds.length}/{botList.length})
                    </span>
                    {botList.length > 1 && (
                      <button
                        type="button"
                        onClick={toggleSelectAll}
                        className="text-[10px] text-emerald-400 hover:underline font-normal cursor-pointer"
                      >
                        {selectedBotIds.length === botList.length ? "Batal Semua" : "Pilih Semua"}
                      </button>
                    )}
                  </div>
                  <div className="h-px bg-zinc-800/80 my-1" />
                  {botList.length === 0 ? (
                    <div className="p-3 text-center text-xs text-zinc-500">
                      Tidak ada akun bot yang terhubung
                    </div>
                  ) : (
                    botList.map((b) => {
                      const isChecked = selectedBotIds.includes(b.botId);
                      return (
                        <div
                          key={b.botId}
                          onClick={() => toggleBot(b.botId)}
                          className={`flex items-center gap-2.5 px-2.5 py-2 rounded-lg cursor-pointer transition-colors ${
                            isChecked ? "bg-zinc-900/90" : "hover:bg-zinc-900/50"
                          }`}
                        >
                          <div className={`h-4 w-4 rounded border flex items-center justify-center shrink-0 transition-colors ${
                            isChecked ? "bg-emerald-500 border-emerald-400 text-zinc-950" : "border-zinc-700 bg-zinc-950"
                          }`}>
                            {isChecked && <Check className="h-3 w-3 stroke-[3]" />}
                          </div>
                          <div className="flex flex-col min-w-0 pr-1">
                            <span className="font-semibold text-xs text-zinc-100 truncate">
                              {b.name || b.botId}
                            </span>
                            <span className="text-[10px] font-mono text-emerald-400 font-bold">
                              {formatRupiah(b.currentCash || 0)}
                            </span>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              )}
            </div>
          </div>

        </div>
      </header>

      {/* 2. Main Content Viewport */}
      <main className={`w-full space-y-4 sm:space-y-5 ${
        isEmbedded ? "pt-1" : "flex-1 max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-6 pb-24 sm:pb-12"
      }`}>

        {/* Toolbar: Search & 100% In-Game Custom Dropdown Filters (Bukan Default Browser) */}
        <div className="flex flex-col md:flex-row gap-2.5 sm:gap-3 items-stretch md:items-center justify-between">
          
          {/* Input Search */}
          <div className="relative w-full md:w-80">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari nama mobil (Innova, RX7, Supra)..."
              className="w-full h-9 pl-9 pr-8 rounded-xl bg-zinc-900/80 border border-zinc-800 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-2.5 top-2.5 text-zinc-500 hover:text-zinc-300 p-0.5"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>

          {/* Sisi Kanan: Total Unit + Dropdown Pass + Dropdown Sort + Refresh */}
          <div className="flex items-center gap-2 flex-wrap sm:flex-nowrap justify-between md:justify-end">
            
            <Badge variant="secondary" className="text-[10px] sm:text-xs font-mono px-2.5 py-1.5 bg-zinc-900 border-zinc-800 text-zinc-300 shrink-0">
              {filteredCars.length} Unit
            </Badge>

            {/* 1. Custom Dropdown Filter PASS (Sesuai In-Game FilterFrame.Pass) */}
            <div className="relative" ref={passDropdownRef}>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIsPassDropdownOpen((prev) => !prev)}
                className="h-9 px-2.5 sm:px-3 gap-1.5 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 text-xs font-bold text-zinc-200 transition-all shadow-sm"
              >
                <span className="text-zinc-400 font-normal hidden sm:inline">Pass:</span>
                <span className="truncate max-w-[90px] sm:max-w-none text-emerald-400">
                  {PASS_OPTIONS.find((p) => p.value === selectedPass)?.label.replace(/\s*\(.*\)/, "") || "Pass"}
                </span>
                <ChevronDown className={`h-3.5 w-3.5 text-zinc-400 shrink-0 transition-transform duration-200 ${isPassDropdownOpen ? "rotate-180" : ""}`} />
              </Button>

              {isPassDropdownOpen && (
                <div className="absolute left-0 md:right-0 md:left-auto mt-2 w-52 overflow-hidden rounded-xl border border-zinc-800 bg-zinc-950/95 backdrop-blur-xl p-1.5 text-zinc-200 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-150">
                  <div className="px-2 py-1.5 text-[10px] font-bold uppercase tracking-wider text-zinc-400">
                    Filter Pass (In-Game CDID)
                  </div>
                  <div className="h-px bg-zinc-800/80 my-1" />
                  {PASS_OPTIONS.map((opt) => {
                    const isSelected = selectedPass === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => {
                          setSelectedPass(opt.value);
                          setIsPassDropdownOpen(false);
                        }}
                        className={`w-full text-left flex items-center justify-between px-2.5 py-1.5 text-xs rounded-lg transition-colors cursor-pointer ${
                          isSelected ? "bg-emerald-500/15 text-emerald-400 font-bold" : "hover:bg-zinc-900 text-zinc-300"
                        }`}
                      >
                        <span>{opt.label}</span>
                        {isSelected && <Check className="h-3.5 w-3.5 text-emerald-400" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* 2. Custom Dropdown Filter SORT (Sesuai In-Game FilterFrame.Sort) */}
            <div className="relative" ref={sortDropdownRef}>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIsSortDropdownOpen((prev) => !prev)}
                className="h-9 px-2.5 sm:px-3 gap-1.5 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 text-xs font-bold text-zinc-200 transition-all shadow-sm"
              >
                <span className="text-zinc-400 font-normal hidden sm:inline">Sort:</span>
                <span className="truncate max-w-[95px] sm:max-w-none text-cyan-400">
                  {SORT_OPTIONS.find((s) => s.value === sortBy)?.label.replace(/\s*\(.*\)/, "") || "Sort"}
                </span>
                <ChevronDown className={`h-3.5 w-3.5 text-zinc-400 shrink-0 transition-transform duration-200 ${isSortDropdownOpen ? "rotate-180" : ""}`} />
              </Button>

              {isSortDropdownOpen && (
                <div className="absolute right-0 mt-2 w-56 overflow-hidden rounded-xl border border-zinc-800 bg-zinc-950/95 backdrop-blur-xl p-1.5 text-zinc-200 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-150">
                  <div className="px-2 py-1.5 text-[10px] font-bold uppercase tracking-wider text-zinc-400">
                    Sortir (In-Game CDID)
                  </div>
                  <div className="h-px bg-zinc-800/80 my-1" />
                  {SORT_OPTIONS.map((opt) => {
                    const isSelected = sortBy === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => {
                          setSortBy(opt.value);
                          setIsSortDropdownOpen(false);
                        }}
                        className={`w-full text-left flex items-center justify-between px-2.5 py-1.5 text-xs rounded-lg transition-colors cursor-pointer ${
                          isSelected ? "bg-cyan-500/15 text-cyan-400 font-bold" : "hover:bg-zinc-900 text-zinc-300"
                        }`}
                      >
                        <span>{opt.label}</span>
                        {isSelected && <Check className="h-3.5 w-3.5 text-cyan-400" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Refresh Button */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                if (queryBot?.botId) {
                  const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
                  onFetchCars(queryBot.botId, dKey);
                }
              }}
              title="Refresh Katalog dari Game"
              className="h-9 w-9 p-0 border-zinc-800 hover:bg-zinc-800 shrink-0 active:scale-95 shadow-sm"
            >
              <RefreshCw className="h-3.5 w-3.5 text-zinc-400" />
            </Button>
          </div>
        </div>

        {/* 3. Catalog Grid (2 Kolom di Mobile, 3-4 di Desktop) */}
        {filteredCars.length === 0 ? (
          <div className="py-16 sm:py-20 text-center rounded-2xl border border-zinc-800 bg-zinc-900/30 px-4">
            <Car className="h-10 w-10 sm:h-12 sm:w-12 text-zinc-600 mx-auto mb-3" />
            <h3 className="text-xs sm:text-sm font-bold text-zinc-300">Tidak ada mobil yang sesuai filter</h3>
            <p className="text-[11px] sm:text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
              Coba ubah opsi pencarian, showroom, atau filter Pass di atas.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2.5 sm:gap-4">
            {displayedCars.map((car) => {
              const imgUrl = car.assetId ? `/api/car-thumbnail?id=${car.assetId}` : null;

              return (
                <Card
                  key={car.id}
                  className="border-zinc-800 bg-gradient-to-b from-zinc-900/70 to-zinc-950/70 overflow-hidden flex flex-col hover:border-zinc-700 transition-all group shadow-sm hover:shadow-lg"
                >
                  {/* Thumbnail Image Container */}
                  <div className="relative aspect-video w-full bg-zinc-950/90 overflow-hidden border-b border-zinc-800/60 flex items-center justify-center">
                    {imgUrl ? (
                      <img
                        src={imgUrl}
                        alt={car.name}
                        loading="lazy"
                        referrerPolicy="no-referrer"
                        className="w-full h-full object-contain p-1.5 sm:p-2 group-hover:scale-105 transition-transform duration-300 z-10"
                        onError={(e) => {
                          e.target.style.display = "none";
                          const fb = e.target.parentElement.querySelector(".car-fallback");
                          if (fb) fb.classList.remove("hidden");
                        }}
                      />
                    ) : null}
                    
                    {/* Fallback Display */}
                    <div className={`car-fallback ${imgUrl ? "hidden" : "flex"} flex-col items-center justify-center text-zinc-600 absolute inset-0`}>
                      <Car className="h-7 w-7 sm:h-10 sm:w-10 text-zinc-700 mb-1" />
                      <span className="text-[9px] sm:text-[10px] font-mono text-zinc-500 uppercase">{car.dealer}</span>
                    </div>

                    {/* Badges: LIMITED (Merah) & NEW (Hijau) Persis In-Game CDID */}
                    <div className="absolute top-1.5 left-1.5 sm:top-2 sm:left-2 flex items-center gap-1 z-20">
                      {car.isLimited && (
                        <span className="text-[8px] sm:text-[9px] font-black uppercase tracking-wider bg-rose-600 text-white border border-rose-500/80 shadow-md shadow-rose-600/40 px-1.5 py-0.5 rounded-md leading-none animate-pulse">
                          LIMITED!
                        </span>
                      )}
                      {car.isNew && (
                        <span className="text-[8px] sm:text-[9px] font-black uppercase tracking-wider bg-emerald-600 text-white border border-emerald-500/80 shadow-md shadow-emerald-600/40 px-1.5 py-0.5 rounded-md leading-none">
                          NEW!
                        </span>
                      )}
                    </div>

                    <Badge
                      variant="secondary"
                      className="absolute top-1.5 right-1.5 sm:top-2 sm:right-2 text-[8px] sm:text-[9px] font-mono bg-zinc-900/90 text-zinc-300 border border-zinc-700/60 z-20 px-1.5 py-0"
                    >
                      {car.dealer}
                    </Badge>
                  </div>

                  {/* Car Details */}
                  <CardContent className="p-2.5 sm:p-4 flex-1 flex flex-col justify-between space-y-2 sm:space-y-3">
                    <div>
                      <h3 className="text-[11px] sm:text-xs font-bold text-zinc-100 line-clamp-2 leading-tight group-hover:text-emerald-400 transition-colors min-h-[1.75rem] sm:min-h-[2rem]">
                        {car.name}
                      </h3>

                      {/* Status Gamepass di bawah nama mobil */}
                      <div className="mt-1 mb-1">
                        {car.isGamepass || (car.gamepass && car.gamepass !== "None Gamepass") ? (
                          <span className="inline-block text-[9px] sm:text-[10px] font-bold text-amber-400 bg-amber-500/10 border border-amber-500/25 px-1.5 py-0.5 rounded leading-none">
                            {car.gamepass || "Gamepass"}
                          </span>
                        ) : (
                          <span className="inline-block text-[9px] sm:text-[10px] font-medium text-zinc-500 bg-zinc-900/80 border border-zinc-800 px-1.5 py-0.5 rounded leading-none">
                            None Gamepass
                          </span>
                        )}
                      </div>

                      {/* Specs Badges */}
                      <div className="flex items-center gap-1 sm:gap-2 mt-1.5 sm:mt-2 flex-wrap">
                        <span className="text-[9px] sm:text-[10px] text-zinc-400 font-mono flex items-center gap-0.5 sm:gap-1 bg-zinc-900/60 px-1 sm:px-1.5 py-0.5 rounded border border-zinc-800">
                          <Gauge className="h-2.5 w-2.5 sm:h-3 sm:w-3 text-cyan-400 shrink-0" />
                          {car.topSpeed || 0} KM/H
                        </span>
                        <span className="text-[9px] sm:text-[10px] text-zinc-400 font-mono flex items-center gap-0.5 sm:gap-1 bg-zinc-900/60 px-1 sm:px-1.5 py-0.5 rounded border border-zinc-800">
                          <Zap className="h-2.5 w-2.5 sm:h-3 sm:w-3 text-amber-400 shrink-0" />
                          {car.hp || 0} HP
                        </span>
                        {car.stock !== undefined && car.stock !== null && (
                          <span className={`text-[9px] sm:text-[10px] font-mono font-bold px-1 sm:px-1.5 py-0.5 rounded border ${
                            car.stock === 0
                              ? "text-rose-400 bg-rose-500/10 border-rose-500/20"
                              : "text-amber-400 bg-amber-500/10 border-amber-500/20"
                          }`}>
                            {car.stock === 0 ? "Stok: 0" : `Stok: ${car.stock}`}
                          </span>
                        )}
                      </div>
                    </div>

                    <div className="pt-2 border-t border-zinc-800/80">
                      <div className="flex items-center justify-between mb-1.5 sm:mb-2">
                        <span className="text-[9px] sm:text-[10px] text-zinc-400 uppercase font-bold tracking-wider">
                          Harga
                        </span>
                        <span className="text-[11px] sm:text-xs font-black text-emerald-400 font-mono truncate">
                          {formatRupiah(car.cost)}
                        </span>
                      </div>

                      <Button
                        size="sm"
                        onClick={() => handleOpenBuyModal(car)}
                        className="w-full h-7 sm:h-8 text-[11px] sm:text-xs font-bold transition-all active:scale-95 bg-emerald-500 hover:bg-emerald-400 text-zinc-950 font-black shadow-md shadow-emerald-500/10"
                      >
                        Beli Mobil
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}

        {/* Load More Button */}
        {filteredCars.length > visibleCount && (
          <div className="flex justify-center pt-2 pb-6">
            <Button
              variant="outline"
              onClick={() => setVisibleCount((prev) => prev + 36)}
              className="w-full sm:w-auto px-6 py-2.5 rounded-xl border-zinc-700 bg-zinc-900/90 hover:bg-zinc-800 text-xs font-bold text-zinc-200 shadow-lg hover:border-emerald-500/50 active:scale-95 transition-all"
            >
              Tampilkan Lebih Banyak ({filteredCars.length - visibleCount} mobil tersisa)
            </Button>
          </div>
        )}

      </main>

      {/* 4. Standalone Footer */}
      <footer className="mt-auto border-t border-zinc-900 bg-zinc-950/90 py-5 sm:py-6 px-4 text-center text-[10px] sm:text-xs text-zinc-500">
        <p>OneEight CDID Farming & Showroom Suite • Real-time synchronization with Roblox ReplicatedStorage.CarData</p>
      </footer>

      {/* 5. Buy Confirmation Modal Sesuai Request User */}
      {modalCar && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-zinc-950/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full sm:max-w-md rounded-t-3xl sm:rounded-2xl bg-zinc-900 border-t sm:border border-zinc-800 p-5 sm:p-6 shadow-2xl space-y-4 max-h-[85vh] overflow-y-auto animate-in slide-in-from-bottom-5 duration-200">
            
            {/* Handle Drag Bar untuk Mobile */}
            <div className="w-12 h-1 bg-zinc-700 rounded-full mx-auto sm:hidden -mt-1 mb-2" />

            {/* Preview Gambar Mobil (Sesuai Permintaan) */}
            <div className="relative aspect-video w-full rounded-2xl bg-zinc-950 border border-zinc-800/80 overflow-hidden flex items-center justify-center">
              {modalCar.assetId ? (
                <img
                  src={`/api/car-thumbnail?id=${modalCar.assetId}`}
                  alt={modalCar.name}
                  className="w-full h-full object-contain p-2"
                  onError={(e) => {
                    e.target.style.display = "none";
                  }}
                />
              ) : (
                <Car className="h-12 w-12 text-zinc-700" />
              )}

              <div className="absolute top-2.5 left-2.5 flex items-center gap-1.5 z-20">
                {modalCar.isLimited && (
                  <span className="text-[9px] font-black uppercase tracking-wider bg-rose-600 text-white border border-rose-500 shadow-md shadow-rose-600/30 px-2 py-0.5 rounded-md leading-none">
                    LIMITED!
                  </span>
                )}
                {modalCar.isNew && (
                  <span className="text-[9px] font-black uppercase tracking-wider bg-emerald-600 text-white border border-emerald-500 shadow-md shadow-emerald-600/30 px-2 py-0.5 rounded-md leading-none">
                    NEW!
                  </span>
                )}
              </div>

              <Badge variant="secondary" className="absolute top-2.5 right-2.5 text-[9px] font-mono bg-zinc-900/90 border border-zinc-700 text-zinc-300">
                {modalCar.dealer}
              </Badge>
            </div>

            {/* Nama & Harga Mobil (Tanpa Kotak Kalkulasi Sisa Saldo) */}
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <span className="text-[10px] font-mono text-emerald-400 uppercase tracking-widest font-bold block">
                  Konfirmasi Pembelian
                </span>
                <h3 className="text-sm sm:text-base font-bold text-zinc-100 mt-0.5 truncate">
                  {modalCar.name}
                </h3>
                {/* Status Gamepass di bawah nama mobil */}
                <div className="mt-1">
                  {modalCar.isGamepass || (modalCar.gamepass && modalCar.gamepass !== "None Gamepass") ? (
                    <span className="inline-block text-[10px] font-bold text-amber-400 bg-amber-500/10 border border-amber-500/25 px-2 py-0.5 rounded leading-none">
                      {modalCar.gamepass || "Gamepass"}
                    </span>
                  ) : (
                    <span className="inline-block text-[10px] font-medium text-zinc-500 bg-zinc-900 border border-zinc-800 px-2 py-0.5 rounded leading-none">
                      None Gamepass
                    </span>
                  )}
                </div>
              </div>
              <span className="font-mono font-black text-sm sm:text-base text-emerald-400 shrink-0">
                {formatRupiah(modalCar.cost)}
              </span>
            </div>

            {/* Pilih Warna: Hanya warna bulatan saja tanpa title teks */}
            <div className="flex items-center justify-center gap-3 py-1">
              {PRESET_COLORS.map((c) => (
                <button
                  key={c.name}
                  type="button"
                  onClick={() => setSelectedColor(c)}
                  className={`h-7 w-7 sm:h-8 sm:w-8 rounded-full border-2 transition-all active:scale-95 shrink-0 ${
                    selectedColor.name === c.name
                      ? "border-emerald-400 ring-2 ring-emerald-400/50 scale-110 shadow-md"
                      : "border-zinc-700 hover:border-zinc-500 opacity-80 hover:opacity-100"
                  }`}
                  style={{ backgroundColor: c.hex }}
                  title={c.name}
                />
              ))}
            </div>

            {/* Info Akun Eksekusi */}
            <div className="text-[11px] text-zinc-400 bg-zinc-950/60 p-2.5 rounded-xl border border-zinc-800/80 flex items-center justify-between">
              <span className="flex items-center gap-1.5">
                <Users className="h-3.5 w-3.5 text-zinc-400" />
                Eksekusi Pembelian:
              </span>
              <span className="font-semibold text-zinc-200">
                {selectedBotIds.length} Akun Terpilih
              </span>
            </div>

            {selectedBotIds.length === 0 && (
              <div className="flex items-center gap-2 p-2.5 rounded-lg bg-amber-500/10 border border-amber-500/20 text-amber-400 text-xs">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>Pilih minimal 1 akun di dropdown atas untuk mengeksekusi pembelian.</span>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex items-center gap-2 pt-1 pb-1 sm:pb-0">
              <Button
                variant="outline"
                className="flex-1 h-10 sm:h-9 border-zinc-700 active:scale-95"
                onClick={() => setModalCar(null)}
                disabled={buyStatus !== null}
              >
                Batal
              </Button>
              <Button
                className="flex-1 h-10 sm:h-9 bg-emerald-500 hover:bg-emerald-400 text-zinc-950 font-black active:scale-95"
                onClick={handleConfirmBuy}
                disabled={selectedBotIds.length === 0 || buyStatus !== null}
              >
                {buyStatus === "SUBMITTED" ? (
                  <span className="flex items-center gap-1.5">
                    <RefreshCw className="h-3.5 w-3.5 animate-spin" />
                    Mengirim...
                  </span>
                ) : buyStatus === "SUCCESS" ? (
                  <span className="flex items-center gap-1.5 text-emerald-950">
                    <Check className="h-4 w-4" />
                    Berhasil Dibeli!
                  </span>
                ) : (
                  "Konfirmasi Beli"
                )}
              </Button>
            </div>

          </div>
        </div>
      )}

    </div>
  );
}
