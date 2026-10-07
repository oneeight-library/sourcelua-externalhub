import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { formatRupiah } from "@/lib/utils.js";
import {
  ArrowLeft,
  Car,
  Search,
  SlidersHorizontal,
  Coins,
  Check,
  AlertCircle,
  Sparkles,
  Gauge,
  Zap,
  Tag,
  RefreshCw,
  Store
} from "lucide-react";

// Urutan dan pengelompokan resmi dealer CDID sesuai game
export const CDID_DEALERS_CONFIG = [
  { key: "Semua Dealer", label: "Semua Dealer", badge: "Katalog" },
  { key: "77", label: "Dealer 77", badge: "Utama" },
  { key: "Bandung", label: "Bekas Bandung", badge: "Used Car" },
  { key: "Otnas", label: "Otnas", badge: "JDM & Klasik" },
  { key: "Premium", label: "Premium", badge: "Supercar" },
  { key: "Toyota", label: "Toyota" },
  { key: "Honda", label: "Honda" },
  { key: "Hyundai", label: "Hyundai" },
  { key: "Mitsubishi", label: "Mitsubishi" },
  { key: "MercedesBenz", label: "Mercedes-Benz" },
  { key: "Suzuki", label: "Suzuki" },
  { key: "Daihatsu", label: "Daihatsu" },
  { key: "KIA", label: "KIA" },
  { key: "Nissan", label: "Nissan" },
  { key: "Mazda", label: "Mazda" },
  { key: "Lexus", label: "Lexus" },
  { key: "Wuling", label: "Wuling" },
  { key: "Audi", label: "Audi" },
  { key: "VW", label: "Volkswagen" },
  { key: "DIR", label: "DIR (BYD)" },
  { key: "Chery", label: "Chery" },
  { key: "Jaecoo", label: "Jaecoo" },
  { key: "Geely", label: "Geely" },
  { key: "Shehua", label: "Shehua (Denza)" },
  { key: "SLM", label: "SLM" },
  { key: "Komersial", label: "Komersial", badge: "Truk & Bus" }
];

export function normalizeDealer(str) {
  if (!str) return "";
  const s = str.toLowerCase().replace(/\s+/g, "").replace(/[^a-z0-9]/g, "");
  if (s === "dealer77" || s === "utama") return "77";
  if (s === "bekasbandung") return "bandung";
  if (s === "komersil") return "komersial";
  if (s === "volkswagen") return "vw";
  if (s === "byd") return "dir";
  if (s === "denza" || s === "yangwang") return "shehua";
  return s;
}

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

  // Sync initialDealer if URL prop changes
  React.useEffect(() => {
    if (initialDealer) {
      setSelectedDealer(initialDealer);
    }
  }, [initialDealer]);

  // Dynamic merged dealer list: Config items + any extras from active bot memory
  const dealerOptions = React.useMemo(() => {
    const list = [...CDID_DEALERS_CONFIG];
    const seen = new Set(list.map((d) => normalizeDealer(d.key)));

    if (activeBot?.dealerList && Array.isArray(activeBot.dealerList)) {
      activeBot.dealerList.forEach((raw) => {
        const norm = normalizeDealer(raw);
        if (!seen.has(norm) && raw.trim() !== "") {
          seen.add(norm);
          list.push({ key: raw, label: raw, badge: "In-Game" });
        }
      });
    }
    return list;
  }, [activeBot?.dealerList]);

  // Request cars from active bot when dealer changes
  React.useEffect(() => {
    if (activeBot && activeBot.botId) {
      const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
      onFetchCars(activeBot.botId, dKey);
    }
  }, [selectedDealer, activeBot?.botId, onFetchCars]);

  const dealerKey = normalizeDealer(selectedDealer === "Semua Dealer" ? "all" : selectedDealer);
  const rawCars = dealerCatalog[dealerKey] || dealerCatalog["all"] || [];

  // Filter cars based on dealer & search query
  const filteredCars = React.useMemo(() => {
    const selNorm = normalizeDealer(selectedDealer);
    return rawCars
      .filter((car) => {
        const carNorm = normalizeDealer(car.dealer);
        const matchesDealer =
          selectedDealer === "Semua Dealer" ||
          carNorm === selNorm ||
          carNorm.includes(selNorm) ||
          selNorm.includes(carNorm);

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

  return (
    <div className="w-full space-y-6">
      
      {/* 1. Header Bar: Navigation & Player Cash */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-2xl bg-zinc-900/60 border border-zinc-800 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={onBackToDashboard}
            className="h-9 px-3 gap-1.5 border-zinc-700 hover:bg-zinc-800 text-xs font-semibold"
          >
            <ArrowLeft className="h-4 w-4" />
            Dashboard
          </Button>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base sm:text-lg font-black tracking-tight text-zinc-100 flex items-center gap-2">
                <Store className="h-5 w-5 text-emerald-400" />
                CDID Showroom Online
              </h1>
              <Badge variant="emerald" className="text-[10px] font-mono px-2 py-0.5">
                Live Game Sync
              </Badge>
            </div>
            <p className="text-xs text-zinc-400">
              Lihat katalog mobil lengkap dan beli unit langsung dari in-game memory.
            </p>
          </div>
        </div>

        {/* Player Cash Display */}
        <div className="flex items-center gap-3 bg-zinc-950/80 px-4 py-2.5 rounded-xl border border-zinc-800/80 shrink-0">
          <Coins className="h-5 w-5 text-emerald-400 shrink-0" />
          <div>
            <span className="text-[10px] uppercase font-bold text-zinc-400 block tracking-wider">
              Saldo Akun ({activeBot?.name || "Bot"})
            </span>
            <span className="text-sm sm:text-base font-black text-emerald-400 font-mono">
              {formatRupiah(playerCash)}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Filter & Controls Bar */}
      <div className="space-y-3">
        {/* Horizontal Scrolling Dealer Badges (Persis Game CDID) */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-zinc-800">
          {dealerOptions.map((item) => {
            const isSelected = normalizeDealer(selectedDealer) === normalizeDealer(item.key);
            return (
              <button
                key={item.key}
                onClick={() => {
                  setSelectedDealer(item.key);
                  const cleanKey = item.key.replace(/\s+/g, "_").toLowerCase();
                  if (typeof window !== "undefined") {
                    window.history.replaceState(null, "", item.key === "Semua Dealer" ? "/cdid_dealer" : `/cdid_${cleanKey}`);
                  }
                }}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all border flex items-center gap-1.5 ${
                  isSelected
                    ? "bg-emerald-500 text-zinc-950 border-emerald-400 shadow-md shadow-emerald-500/20"
                    : "bg-zinc-900/60 text-zinc-400 border-zinc-800 hover:text-zinc-200 hover:border-zinc-700"
                }`}
              >
                <span>{item.label}</span>
                {item.badge && (
                  <span className={`text-[9px] px-1 py-0.2 rounded ${isSelected ? "bg-zinc-950/20 text-zinc-950" : "bg-zinc-800 text-zinc-400"}`}>
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Search & Sort Controls */}
        <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
          <div className="relative w-full sm:w-80">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-zinc-500" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari nama mobil (cth: Innova, RX7, Supra)..."
              className="w-full h-9 pl-9 pr-3 rounded-xl bg-zinc-900/80 border border-zinc-800 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700"
            />
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <span className="text-xs text-zinc-400">Urutkan:</span>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="h-9 px-3 rounded-xl bg-zinc-900/80 border border-zinc-800 text-xs text-zinc-200 focus:outline-none focus:border-zinc-700"
            >
              <option value="price_asc">Harga: Termurah</option>
              <option value="price_desc">Harga: Termahal</option>
              <option value="speed_desc">Top Speed Tertinggi</option>
              <option value="hp_desc">Tenaga Kuda (HP) Tertinggi</option>
            </select>
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
              className="h-9 w-9 p-0 border-zinc-800 hover:bg-zinc-800"
            >
              <RefreshCw className="h-3.5 w-3.5 text-zinc-400" />
            </Button>
          </div>
        </div>
      </div>

      {/* 3. Catalog Grid */}
      {filteredCars.length === 0 ? (
        <div className="py-20 text-center rounded-2xl border border-zinc-800 bg-zinc-900/30">
          <Car className="h-12 w-12 text-zinc-600 mx-auto mb-3" />
          <h3 className="text-sm font-bold text-zinc-300">Memuat Katalog Mobil dari Game CDID...</h3>
          <p className="text-xs text-zinc-500 mt-1 max-w-sm mx-auto">
            Sedang mensinkronkan daftar kendaraan dari server game CDID.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {filteredCars.map((car) => {
            const canAfford = playerCash >= car.cost;
            const imgUrl = car.assetId ? `/api/car-thumbnail?id=${car.assetId}` : null;

            return (
              <Card
                key={car.id}
                className="border-zinc-800 bg-gradient-to-b from-zinc-900/70 to-zinc-950/70 overflow-hidden flex flex-col hover:border-zinc-700 transition-all group"
              >
                {/* Thumbnail Image Container */}
                <div className="relative aspect-video w-full bg-zinc-950/90 overflow-hidden border-b border-zinc-800/60 flex items-center justify-center">
                  {imgUrl ? (
                    <img
                      src={imgUrl}
                      alt={car.name}
                      loading="lazy"
                      referrerPolicy="no-referrer"
                      className="w-full h-full object-contain p-2 group-hover:scale-105 transition-transform duration-300 z-10"
                      onError={(e) => {
                        e.target.style.display = "none";
                        const fb = e.target.parentElement.querySelector(".car-fallback");
                        if (fb) fb.classList.remove("hidden");
                      }}
                    />
                  ) : null}
                  
                  {/* Fallback Display */}
                  <div className={`car-fallback ${imgUrl ? "hidden" : "flex"} flex-col items-center justify-center text-zinc-600 absolute inset-0`}>
                    <Car className="h-10 w-10 text-zinc-700 mb-1" />
                    <span className="text-[10px] font-mono text-zinc-500 uppercase">{car.dealer}</span>
                  </div>

                  <Badge
                    variant="secondary"
                    className="absolute top-2 right-2 text-[9px] font-mono bg-zinc-900/90 text-zinc-300 border border-zinc-700/60 z-20"
                  >
                    {car.dealer}
                  </Badge>
                </div>

                {/* Car Details */}
                <CardContent className="p-4 flex-1 flex flex-col justify-between space-y-3">
                  <div>
                    <h3 className="text-xs font-bold text-zinc-100 line-clamp-2 leading-tight group-hover:text-emerald-400 transition-colors">
                      {car.name}
                    </h3>
                    {/* Specs Badges */}
                    <div className="flex items-center gap-2 mt-2">
                      <span className="text-[10px] text-zinc-400 font-mono flex items-center gap-1 bg-zinc-900/60 px-1.5 py-0.5 rounded border border-zinc-800">
                        <Gauge className="h-3 w-3 text-cyan-400" />
                        {car.topSpeed || 0} KM/H
                      </span>
                      <span className="text-[10px] text-zinc-400 font-mono flex items-center gap-1 bg-zinc-900/60 px-1.5 py-0.5 rounded border border-zinc-800">
                        <Zap className="h-3 w-3 text-amber-400" />
                        {car.hp || 0} HP
                      </span>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-zinc-800/80">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[10px] text-zinc-400 uppercase font-bold tracking-wider">
                        Harga
                      </span>
                      <span className="text-xs font-black text-emerald-400 font-mono">
                        {formatRupiah(car.cost)}
                      </span>
                    </div>

                    <Button
                      size="sm"
                      onClick={() => handleOpenBuyModal(car)}
                      className={`w-full text-xs font-bold transition-all ${
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

      {/* 4. Buy Confirmation Modal */}
      {modalCar && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full max-w-md rounded-2xl bg-zinc-900 border border-zinc-800 p-6 shadow-2xl space-y-4">
            <div className="flex items-start justify-between">
              <div>
                <span className="text-[10px] font-mono text-emerald-400 uppercase tracking-widest font-bold">
                  Konfirmasi Pembelian
                </span>
                <h3 className="text-base font-bold text-zinc-100 mt-1">
                  {modalCar.name}
                </h3>
              </div>
              <Badge variant="outline" className="border-zinc-700 text-zinc-300">
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

            {/* Color Selection */}
            <div>
              <label className="text-xs font-semibold text-zinc-300 block mb-2">
                Pilih Warna Kendaraan:
              </label>
              <div className="flex items-center gap-2 flex-wrap">
                {PRESET_COLORS.map((c) => (
                  <button
                    key={c.name}
                    onClick={() => setSelectedColor(c)}
                    className={`h-8 px-2.5 rounded-lg text-xs font-medium border flex items-center gap-2 transition-all ${
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
            <div className="flex items-center gap-2 pt-2">
              <Button
                variant="outline"
                className="flex-1 border-zinc-700"
                onClick={() => setModalCar(null)}
                disabled={buyStatus !== null}
              >
                Batal
              </Button>
              <Button
                className="flex-1 bg-emerald-500 hover:bg-emerald-400 text-zinc-950 font-black"
                onClick={handleConfirmBuy}
                disabled={playerCash < modalCar.cost || buyStatus !== null}
              >
                {buyStatus === "SUBMITTED" ? (
                  <span className="flex items-center gap-1.5">
                    <RefreshCw className="h-3.5 w-3.5 animate-spin" />
                    Mengirim ke Game...
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
