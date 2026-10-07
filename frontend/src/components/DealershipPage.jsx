import * as React from "react";
import { Card, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/ui/select.jsx";
import { formatRupiah } from "@/lib/utils.js";
import {
  ArrowLeft,
  Car,
  Search,
  Coins,
  Check,
  AlertCircle,
  Gauge,
  Zap,
  RefreshCw,
  Store,
  X,
  UserCheck
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

const PRESET_COLORS = [
  { name: "Putih", rgb: { r: 255, g: 255, b: 255 }, hex: "#ffffff" },
  { name: "Hitam", rgb: { r: 15, g: 15, b: 15 }, hex: "#111111" },
  { name: "Silver", rgb: { r: 192, g: 192, b: 192 }, hex: "#c0c0c0" },
  { name: "Abu-abu", rgb: { r: 80, g: 80, b: 80 }, hex: "#505050" },
  { name: "Merah", rgb: { r: 200, g: 20, b: 20 }, hex: "#c81414" },
  { name: "Biru", rgb: { r: 20, g: 80, b: 200 }, hex: "#1450c8" },
  { name: "Kuning", rgb: { r: 240, g: 190, b: 10 }, hex: "#f0be0a" },
];

export function DealershipPage({
  initialDealer = "Semua Dealer",
  bots,
  activeBot,
  onSelectBot,
  dealerCatalog,
  onFetchCars,
  onBuyCar,
  onBackToDashboard
}) {
  const [selectedDealer, setSelectedDealer] = React.useState(initialDealer);
  const [searchQuery, setSearchQuery] = React.useState("");
  const [sortBy, setSortBy] = React.useState("price_asc");
  const [modalCar, setModalCar] = React.useState(null);
  const [selectedColor, setSelectedColor] = React.useState(PRESET_COLORS[0]);
  const [buyStatus, setBuyStatus] = React.useState(null);
  const [visibleCount, setVisibleCount] = React.useState(36);

  // Reset pagination saat dealer atau search query berganti
  React.useEffect(() => {
    setVisibleCount(36);
  }, [selectedDealer, searchQuery]);

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

  // Request cars from active bot only when dealer actually changes (prevent infinite loops)
  const fetchedRef = React.useRef({ botId: null, dealer: null });
  React.useEffect(() => {
    if (activeBot && activeBot.botId) {
      const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
      if (fetchedRef.current.botId === activeBot.botId && fetchedRef.current.dealer === dKey) {
        return;
      }
      fetchedRef.current = { botId: activeBot.botId, dealer: dKey };
      onFetchCars(activeBot.botId, dKey);
    }
  }, [selectedDealer, activeBot?.botId, onFetchCars]);

  const dealerKey = (selectedDealer === "Semua Dealer" ? "all" : selectedDealer).toLowerCase().replace(/\s+/g, "");
  const rawCars = dealerCatalog[dealerKey] || dealerCatalog["all"] || [];

  // PENGELOMPOKAN 100% MURNI SESUAI car.dealer (car.Dealership.Value dari CarData)
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

        return matchesDealer && matchesSearch;
      })
      .sort((a, b) => {
        if (sortBy === "price_asc") return a.cost - b.cost;
        if (sortBy === "price_desc") return b.cost - a.cost;
        if (sortBy === "speed_desc") return (b.topSpeed || 0) - (a.topSpeed || 0);
        if (sortBy === "hp_desc") return (b.hp || 0) - (a.hp || 0);
        return 0;
      });
  }, [rawCars, selectedDealer, searchQuery, sortBy]);

  const displayedCars = React.useMemo(() => {
    return filteredCars.slice(0, visibleCount);
  }, [filteredCars, visibleCount]);

  const playerCash = activeBot?.currentCash || 0;

  const handleOpenBuyModal = (car) => {
    setModalCar(car);
    setSelectedColor(PRESET_COLORS[0]);
    setBuyStatus(null);
  };

  const handleConfirmBuy = () => {
    if (!modalCar || !activeBot) return;
    onBuyCar(activeBot.botId, modalCar.id, modalCar.dealer, selectedColor.rgb);
    setBuyStatus("SUBMITTED");
    setTimeout(() => {
      setBuyStatus("SUCCESS");
      setTimeout(() => {
        setModalCar(null);
        setBuyStatus(null);
      }, 1500);
    }, 800);
  };

  const botList = bots ? Array.from(bots.values()) : [];

  return (
    <div className="h-screen h-[100dvh] w-full overflow-y-auto overflow-x-hidden bg-zinc-950 text-zinc-100 flex flex-col selection:bg-emerald-500/20 selection:text-emerald-300 overscroll-contain">
      
      {/* 1. Header Navigasi Mandiri (Mobile-Optimized & Sticky) */}
      <header className="sticky top-0 z-40 w-full border-b border-zinc-800/80 bg-zinc-950/90 backdrop-blur-xl">
        <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 h-14 sm:h-16 flex items-center justify-between gap-2 sm:gap-4">
          
          {/* Left: Tombol Kembali & Judul */}
          <div className="flex items-center gap-2 sm:gap-3 shrink-0">
            <Button
              variant="outline"
              size="sm"
              onClick={onBackToDashboard}
              className="h-8 sm:h-9 px-2 sm:px-3 gap-1.5 border-zinc-800 bg-zinc-900/90 hover:bg-zinc-800 hover:text-zinc-100 text-xs font-semibold text-zinc-200 shadow-sm active:scale-95 transition-all"
            >
              <ArrowLeft className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-zinc-400" />
              <span className="hidden xs:inline sm:inline">Dashboard</span>
            </Button>

            <div className="h-4 w-px bg-zinc-800 hidden sm:block" />

            <div className="flex items-center gap-2">
              <div className="h-8 w-8 sm:h-9 sm:w-9 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 shadow-inner shrink-0">
                <Store className="h-4 w-4 sm:h-5 sm:w-5" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs sm:text-base font-black tracking-tight text-zinc-100 uppercase">
                    CDID Showroom
                  </span>
                  <Badge variant="emerald" className="text-[8px] sm:text-[9px] font-mono px-1 sm:px-1.5 py-0 leading-tight">
                    Live
                  </Badge>
                </div>
                <p className="text-[10px] text-zinc-400 hidden md:block">
                  Katalog Kendaraan Resmi • Sinkronisasi In-Game
                </p>
              </div>
            </div>
          </div>

          {/* Right: Akun Selector & Saldo */}
          <div className="flex items-center gap-1.5 sm:gap-3 shrink-0">
            {/* Akun Selector Dropdown */}
            {botList.length > 1 && (
              <Select
                value={activeBot?.botId || ""}
                onValueChange={(val) => onSelectBot && onSelectBot(val)}
              >
                <SelectTrigger className="h-8 sm:h-9 w-24 sm:w-40 border-zinc-800 bg-zinc-900/90 text-[11px] sm:text-xs text-zinc-200 px-2 sm:px-3">
                  <UserCheck className="h-3 w-3 mr-1 text-zinc-400 shrink-0 hidden sm:inline" />
                  <SelectValue placeholder="Pilih Akun..." />
                </SelectTrigger>
                <SelectContent className="border-zinc-800 bg-zinc-950 text-zinc-200">
                  {botList.map((b) => (
                    <SelectItem key={b.botId} value={b.botId} className="text-xs">
                      {b.name || b.botId}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}

            {/* Saldo Akun */}
            <div className="flex items-center gap-1.5 sm:gap-2 px-2 sm:px-3 py-1 sm:py-1.5 rounded-xl bg-zinc-900/90 border border-zinc-800 shadow-sm shrink-0">
              <Coins className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-emerald-400 shrink-0" />
              <div>
                <span className="text-[8px] sm:text-[9px] uppercase font-bold text-zinc-400 block tracking-wider leading-none hidden sm:block">
                  Saldo ({activeBot?.name || "Akun"})
                </span>
                <span className="text-[11px] sm:text-sm font-black text-emerald-400 font-mono leading-none">
                  {formatRupiah(playerCash)}
                </span>
              </div>
            </div>
          </div>

        </div>
      </header>

      {/* 2. Main Standalone Content Viewport */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-3 sm:px-6 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-24 sm:pb-12">

        {/* Hero Banner Showcase (Compact on Mobile) */}
        <div className="p-3.5 sm:p-5 rounded-2xl bg-gradient-to-r from-zinc-900/90 via-zinc-900/60 to-zinc-950/90 border border-zinc-800/80 backdrop-blur-md flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4">
          <div>
            <h2 className="text-sm sm:text-lg font-black text-zinc-100 flex items-center gap-2">
              <Car className="h-4 w-4 sm:h-5 sm:w-5 text-emerald-400" />
              Katalog Mobil Resmi CDID
            </h2>
            <p className="text-[11px] sm:text-xs text-zinc-400 mt-0.5 sm:mt-1 max-w-xl leading-relaxed">
              Pilih dan beli kendaraan resmi langsung dari website tanpa harus membuka dealership in-game. Data tersinkron langsung dari CDID CarData.
            </p>
          </div>
          <div className="flex items-center gap-2 self-start sm:self-auto shrink-0">
            <Badge variant="secondary" className="text-[10px] sm:text-xs font-mono px-2 sm:px-2.5 py-0.5 sm:py-1 bg-zinc-900 border-zinc-700">
              {filteredCars.length} Unit
            </Badge>
            <Badge variant="outline" className="text-[10px] sm:text-xs font-mono px-2 sm:px-2.5 py-0.5 sm:py-1 text-emerald-400 border-emerald-500/30 bg-emerald-500/10">
              {selectedDealer}
            </Badge>
          </div>
        </div>

        {/* Horizontal Scrolling Dealer Badges (25 Showroom - Touch Momentum Snap) */}
        <div className="space-y-1.5 sm:space-y-2">
          <div className="flex items-center justify-between px-0.5">
            <span className="text-[11px] sm:text-xs font-bold uppercase tracking-wider text-zinc-400">
              Pilih Showroom ({dealerOptions.length})
            </span>
            <span className="text-[10px] sm:text-[11px] text-zinc-500 font-mono">
              Geser untuk memilih
            </span>
          </div>
          <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scroll-smooth snap-x snap-mandatory scrollbar-none [scrollbar-width:none] [-ms-overflow-style:none] [-webkit-overflow-scrolling:touch]">
            {dealerOptions.map((dealerName) => {
              const isSelected = selectedDealer.toLowerCase().trim() === dealerName.toLowerCase().trim();
              return (
                <button
                  key={dealerName}
                  onClick={() => {
                    setSelectedDealer(dealerName);
                    const cleanKey = dealerName.replace(/\s+/g, "_").toLowerCase();
                    if (typeof window !== "undefined") {
                      window.history.replaceState(null, "", dealerName === "Semua Dealer" ? "/cdid_dealer" : `/cdid_${cleanKey}`);
                    }
                  }}
                  className={`snap-start px-3 py-1.5 sm:px-3.5 sm:py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all border flex items-center gap-1.5 active:scale-95 shrink-0 ${
                    isSelected
                      ? "bg-emerald-500 text-zinc-950 border-emerald-400 shadow-md shadow-emerald-500/20 font-black"
                      : "bg-zinc-900/70 text-zinc-400 border-zinc-800 hover:text-zinc-200 hover:border-zinc-700"
                  }`}
                >
                  <span>{dealerName}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Search, Sort, & Refresh Toolbar (Mobile-Friendly Stack) */}
        <div className="flex flex-col sm:flex-row gap-2 sm:gap-3 items-stretch sm:items-center justify-between">
          <div className="relative w-full sm:w-80">
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

          <div className="flex items-center gap-2 justify-between sm:justify-end">
            <div className="flex items-center gap-1.5 flex-1 sm:flex-none">
              <span className="text-[11px] sm:text-xs text-zinc-400 whitespace-nowrap hidden xs:inline">Urut:</span>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="h-9 w-full sm:w-auto px-2.5 sm:px-3 rounded-xl bg-zinc-900/80 border border-zinc-800 text-xs text-zinc-200 focus:outline-none focus:border-zinc-700"
              >
                <option value="price_asc">Harga: Termurah</option>
                <option value="price_desc">Harga: Termahal</option>
                <option value="speed_desc">Top Speed Tertinggi</option>
                <option value="hp_desc">Tenaga Kuda (HP) Tertinggi</option>
              </select>
            </div>
            
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                if (activeBot?.botId) {
                  const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
                  onFetchCars(activeBot.botId, dKey);
                }
              }}
              title="Refresh Katalog dari Game"
              className="h-9 w-9 p-0 border-zinc-800 hover:bg-zinc-800 shrink-0 active:scale-95"
            >
              <RefreshCw className="h-3.5 w-3.5 text-zinc-400" />
            </Button>
          </div>
        </div>

        {/* 3. Catalog Grid (2 Kolom di Mobile, 3-4 di Desktop) */}
        {filteredCars.length === 0 ? (
          <div className="py-16 sm:py-20 text-center rounded-2xl border border-zinc-800 bg-zinc-900/30 px-4">
            <Car className="h-10 w-10 sm:h-12 sm:w-12 text-zinc-600 mx-auto mb-3" />
            <h3 className="text-xs sm:text-sm font-bold text-zinc-300">Memuat Katalog Mobil dari Game CDID...</h3>
            <p className="text-[11px] sm:text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
              Sedang mensinkronkan daftar kendaraan dari server game CDID. Pastikan bot Roblox sedang online dan terhubung.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2.5 sm:gap-4">
            {displayedCars.map((car) => {
              const canAfford = playerCash >= car.cost;
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
                        className={`w-full h-7 sm:h-8 text-[11px] sm:text-xs font-bold transition-all active:scale-95 ${
                          canAfford
                            ? "bg-emerald-500 hover:bg-emerald-400 text-zinc-950 font-black shadow-md shadow-emerald-500/10"
                            : "bg-zinc-800 hover:bg-zinc-700 text-zinc-300"
                        }`}
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

      {/* 5. Buy Confirmation Modal (Bottom Sheet di Mobile, Centered Modal di Desktop) */}
      {modalCar && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-zinc-950/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full sm:max-w-md rounded-t-3xl sm:rounded-2xl bg-zinc-900 border-t sm:border border-zinc-800 p-5 sm:p-6 shadow-2xl space-y-4 max-h-[85vh] overflow-y-auto animate-in slide-in-from-bottom-5 duration-200">
            
            {/* Handle Drag Bar untuk Mobile */}
            <div className="w-12 h-1 bg-zinc-700 rounded-full mx-auto sm:hidden -mt-1 mb-2" />

            <div className="flex items-start justify-between">
              <div>
                <span className="text-[10px] font-mono text-emerald-400 uppercase tracking-widest font-bold">
                  Konfirmasi Pembelian
                </span>
                <h3 className="text-sm sm:text-base font-bold text-zinc-100 mt-0.5">
                  {modalCar.name}
                </h3>
              </div>
              <Badge variant="outline" className="border-zinc-700 text-zinc-300 text-xs">
                {modalCar.dealer}
              </Badge>
            </div>

            {/* Price & Balance Check */}
            <div className="p-3 rounded-xl bg-zinc-950 border border-zinc-800/80 space-y-2">
              <div className="flex justify-between text-xs">
                <span className="text-zinc-400">Harga Mobil:</span>
                <span className="font-mono font-bold text-emerald-400">
                  {formatRupiah(modalCar.cost)}
                </span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-zinc-400">Saldo Akun:</span>
                <span className="font-mono text-zinc-200">
                  {formatRupiah(playerCash)}
                </span>
              </div>
              <div className="pt-2 border-t border-zinc-800/60 flex justify-between text-xs font-bold">
                <span className="text-zinc-400">Sisa Saldo:</span>
                <span className={`font-mono ${playerCash >= modalCar.cost ? "text-zinc-200" : "text-rose-400"}`}>
                  {formatRupiah(playerCash - modalCar.cost)}
                </span>
              </div>
            </div>

            {playerCash < modalCar.cost && (
              <div className="flex items-center gap-2 p-2.5 rounded-lg bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>Saldo tidak cukup untuk membeli mobil ini.</span>
              </div>
            )}

            {/* Color Selection (Horizontal Scrollable Chips for Mobile) */}
            <div>
              <label className="text-xs font-semibold text-zinc-300 block mb-2">
                Pilih Warna Kendaraan:
              </label>
              <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none [scrollbar-width:none]">
                {PRESET_COLORS.map((c) => (
                  <button
                    key={c.name}
                    onClick={() => setSelectedColor(c)}
                    className={`h-8 px-2.5 rounded-lg text-xs font-medium border flex items-center gap-2 shrink-0 active:scale-95 transition-all ${
                      selectedColor.name === c.name
                        ? "border-emerald-400 bg-zinc-800 text-white ring-1 ring-emerald-400"
                        : "border-zinc-800 bg-zinc-950 text-zinc-400 hover:border-zinc-700"
                    }`}
                  >
                    <span
                      className="h-3.5 w-3.5 rounded-full border border-zinc-700 shrink-0"
                      style={{ backgroundColor: c.hex }}
                    />
                    <span>{c.name}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex items-center gap-2 pt-2 pb-2 sm:pb-0">
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
                disabled={playerCash < modalCar.cost || buyStatus !== null}
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
