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
  RefreshCw
} from "lucide-react";

const ALL_DEALERS = [
  "Semua Dealer",
  "Toyota",
  "Honda",
  "Mitsubishi",
  "Porsche",
  "MercedesBenz",
  "BMW",
  "Audi",
  "Lexus",
  "Hyundai",
  "Wuling",
  "Suzuki",
  "Nissan",
  "Mazda",
  "Daihatsu",
  "KIA",
  "Chery",
  "Geely",
  "Komersial",
  "SLM",
  "DIR",
  "Premium",
  "Otnas",
  "Shehua",
  "Bandung",
  "77"
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

  // Sync initialDealer if URL prop changes
  React.useEffect(() => {
    if (initialDealer) {
      setSelectedDealer(initialDealer);
    }
  }, [initialDealer]);

  // Request cars from active bot when dealer changes
  React.useEffect(() => {
    if (activeBot && activeBot.botId) {
      const dKey = selectedDealer === "Semua Dealer" ? "all" : selectedDealer;
      onFetchCars(activeBot.botId, dKey);
    }
  }, [selectedDealer, activeBot?.botId, onFetchCars]);

  const dealerKey = (selectedDealer === "Semua Dealer" ? "all" : selectedDealer).toLowerCase().replace(/\s+/g, "");
  const rawCars = dealerCatalog[dealerKey] || dealerCatalog["all"] || [];

  // Filter cars based on dealer & search query
  const filteredCars = React.useMemo(() => {
    return rawCars
      .filter((car) => {
        const matchesDealer =
          selectedDealer === "Semua Dealer" ||
          car.dealer?.toLowerCase().replace(/\s+/g, "") === selectedDealer.toLowerCase().replace(/\s+/g, "");
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
                <Car className="h-5 w-5 text-emerald-400" />
                CDID Showroom Online
              </h1>
              <Badge variant="emerald" className="text-[10px] font-mono px-2 py-0.5">
                Live Game Sync
              </Badge>
            </div>
            <p className="text-xs text-zinc-400 mt-0.5">
              Katalog resmi dealer CDID. Pembelian mobil langsung dieksekusi di akun game.
            </p>
          </div>
        </div>

        {/* Saldo Akun Pemain */}
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
        {/* Horizontal Scrolling Dealer Badges */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-zinc-800">
          {ALL_DEALERS.map((dealer) => {
            const isSelected = selectedDealer.toLowerCase() === dealer.toLowerCase();
            return (
              <button
                key={dealer}
                onClick={() => {
                  setSelectedDealer(dealer);
                  const cleanKey = dealer.replace(/\s+/g, "_").toLowerCase();
                  if (typeof window !== "undefined") {
                    window.history.replaceState(null, "", dealer === "Semua Dealer" ? "/cdid_dealer" : `/cdid_${cleanKey}`);
                  }
                }}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all border ${
                  isSelected
                    ? "bg-emerald-500 text-zinc-950 border-emerald-400 shadow-md shadow-emerald-500/20"
                    : "bg-zinc-900/60 text-zinc-400 border-zinc-800 hover:text-zinc-200 hover:border-zinc-700"
                }`}
              >
                {dealer}
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
            Pastikan akun Roblox aktif dan terhubung ke server game CDID.
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
                <div className="relative aspect-video w-full bg-zinc-950/80 overflow-hidden border-b border-zinc-800/60 flex items-center justify-center">
                  {imgUrl ? (
                    <img
                      src={imgUrl}
                      alt={car.name}
                      loading="lazy"
                      className="w-full h-full object-contain p-2 group-hover:scale-105 transition-transform duration-300"
                      onError={(e) => {
                        e.target.style.display = "none";
                      }}
                    />
                  ) : (
                    <Car className="h-10 w-10 text-zinc-700" />
                  )}
                  <Badge
                    variant="secondary"
                    className="absolute top-2 right-2 text-[9px] font-mono bg-zinc-900/90 text-zinc-300 border border-zinc-700/60"
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

                  {/* Price & Buy Button */}
                  <div className="pt-2 border-t border-zinc-800/60 space-y-2">
                    <div>
                      <span className="text-[9px] uppercase font-bold text-zinc-500 block">Harga</span>
                      <span className="text-sm font-black text-emerald-400 font-mono">
                        {formatRupiah(car.cost)}
                      </span>
                    </div>

                    <Button
                      size="sm"
                      variant={canAfford ? "emerald" : "secondary"}
                      disabled={!canAfford}
                      className="w-full h-8 text-xs font-bold"
                      onClick={() => handleOpenBuyModal(car)}
                    >
                      {canAfford ? "Beli Mobil" : "Saldo Tidak Cukup"}
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* 4. Purchase Confirmation Modal */}
      {modalCar && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md rounded-2xl border border-zinc-800 bg-zinc-950 p-5 shadow-2xl space-y-4">
            
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <div className="flex items-center gap-2">
                <Car className="h-5 w-5 text-emerald-400" />
                <h3 className="font-bold text-sm text-zinc-100">Konfirmasi Pembelian Mobil</h3>
              </div>
              <Badge variant="outline" className="text-[10px] font-mono">
                {modalCar.dealer}
              </Badge>
            </div>

            {/* Car Preview Image */}
            <div className="aspect-video w-full rounded-xl bg-zinc-900/50 border border-zinc-800 flex items-center justify-center overflow-hidden p-2">
              {modalCar.assetId ? (
                <img
                  src={`/api/car-thumbnail?id=${modalCar.assetId}`}
                  alt={modalCar.name}
                  className="max-h-full object-contain"
                />
              ) : (
                <Car className="h-12 w-12 text-zinc-600" />
              )}
            </div>

            {/* Car Info */}
            <div>
              <h4 className="text-sm font-black text-zinc-100">{modalCar.name}</h4>
              <div className="flex items-center justify-between mt-1">
                <span className="text-xs text-zinc-400">Total Harga:</span>
                <span className="text-base font-black text-emerald-400 font-mono">
                  {formatRupiah(modalCar.cost)}
                </span>
              </div>
            </div>

            {/* Color Swatch Picker */}
            <div className="space-y-1.5 pt-1">
              <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">
                Pilih Warna Cat: <span className="text-zinc-200">{selectedColor.name}</span>
              </span>
              <div className="flex items-center gap-2">
                {PRESET_COLORS.map((col) => {
                  const isColSelected = selectedColor.name === col.name;
                  return (
                    <button
                      key={col.name}
                      onClick={() => setSelectedColor(col)}
                      className={`h-7 w-7 rounded-full border-2 transition-transform flex items-center justify-center ${
                        isColSelected ? "scale-110 border-emerald-400 shadow-md" : "border-zinc-700 hover:scale-105"
                      }`}
                      style={{ backgroundColor: col.hex }}
                    >
                      {isColSelected && (
                        <Check className={`h-3.5 w-3.5 ${col.name === "Putih" ? "text-black" : "text-white"}`} />
                      )}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Status Message */}
            {buyStatus === "SUBMITTED" && (
              <div className="p-3 rounded-xl bg-indigo-950/40 border border-indigo-800/60 text-xs text-indigo-300 flex items-center gap-2 animate-pulse">
                <Sparkles className="h-4 w-4" />
                Mengirim transaksi ke server CDID...
              </div>
            )}
            {buyStatus === "SUCCESS" && (
              <div className="p-3 rounded-xl bg-emerald-950/40 border border-emerald-800/60 text-xs text-emerald-300 flex items-center gap-2">
                <Check className="h-4 w-4 text-emerald-400" />
                Transaksi berhasil diproses di client Roblox!
              </div>
            )}

            {/* Buttons */}
            <div className="flex items-center gap-2 pt-2 border-t border-zinc-800">
              <Button
                variant="outline"
                size="sm"
                className="flex-1 text-xs border-zinc-800"
                onClick={() => setModalCar(null)}
                disabled={buyStatus !== null}
              >
                Batal
              </Button>
              <Button
                variant="emerald"
                size="sm"
                className="flex-1 text-xs font-bold"
                onClick={handleConfirmBuy}
                disabled={buyStatus !== null}
              >
                Beli Sekarang
              </Button>
            </div>

          </div>
        </div>
      )}

    </div>
  );
}
