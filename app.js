let citiesData = [];
let showCleanest = false;
let rankingChart, trendChart, categoryChart, map;

const CPCB_COLORS = {
  Good: "#22c55e",
  Satisfactory: "#84cc16",
  Moderate: "#eab308",
  Poor: "#f97316",
  "Very Poor": "#ef4444",
  Severe: "#991b1b",
};

function getAqiColor(aqi) {
  if (aqi <= 50) return CPCB_COLORS.Good;
  if (aqi <= 100) return CPCB_COLORS.Satisfactory;
  if (aqi <= 200) return CPCB_COLORS.Moderate;
  if (aqi <= 300) return CPCB_COLORS.Poor;
  if (aqi <= 400) return CPCB_COLORS["Very Poor"];
  return CPCB_COLORS.Severe;
}

function getAqiLabel(aqi) {
  if (aqi <= 50) return "Good";
  if (aqi <= 100) return "Satisfactory";
  if (aqi <= 200) return "Moderate";
  if (aqi <= 300) return "Poor";
  if (aqi <= 400) return "Very Poor";
  return "Severe";
}

async function init() {
  const res = await fetch("/api/cities");
  citiesData = await res.json();

  populateCityDropdown();
  initMap();
  renderRankingChart();
  await loadTrends("ALL");

  document.getElementById("citySelect").addEventListener("change", (e) => {
    loadTrends(e.target.value);
  });

  document.getElementById("toggleRankBtn").addEventListener("click", () => {
    showCleanest = !showCleanest;
    renderRankingChart();
  });
}

function populateCityDropdown() {
  const select = document.getElementById("citySelect");
  const sorted = [...citiesData].sort((a, b) => a.city.localeCompare(b.city));
  sorted.forEach((c) => {
    const opt = document.createElement("option");
    opt.value = c.city;
    opt.textContent = `${c.city} (${c.state})`;
    select.appendChild(opt);
  });
}

function initMap() {
  map = L.map("indiaMap").setView([22.5, 80.5], 4.5);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 18,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(map);

  citiesData.forEach((c) => {
    const color = getAqiColor(c.avg_india_aqi);
    const marker = L.circleMarker([c.latitude, c.longitude], {
      radius: 8,
      fillColor: color,
      color: "#ffffff",
      weight: 1,
      fillOpacity: 0.85,
    }).addTo(map);

    marker.bindPopup(`
      <strong>${c.city}</strong> (${c.region})<br/>
      Avg AQI: <b>${c.avg_india_aqi}</b><br/>
      Avg PM2.5: <b>${c.avg_pm2_5} µg/m³</b><br/>
      Clean Days: <b>${c.pct_clean_days}%</b>
    `);

    marker.on("click", () => {
      document.getElementById("citySelect").value = c.city;
      loadTrends(c.city);
    });
  });
}

function renderRankingChart() {
  const subset = showCleanest
    ? [...citiesData].sort((a, b) => a.avg_india_aqi - b.avg_india_aqi).slice(0, 10)
    : citiesData.slice(0, 10);

  document.getElementById("rankingTitle").textContent = showCleanest
    ? "Top 10 Cleanest Cities (Avg India AQI)"
    : "Top 10 Most Polluted Cities (Avg India AQI)";
  document.getElementById("toggleRankBtn").textContent = showCleanest
    ? "Show Most Polluted 10"
    : "Show Cleanest 10";

  if (rankingChart) rankingChart.destroy();
  rankingChart = new Chart(document.getElementById("rankingChart"), {
    type: "bar",
    data: {
      labels: subset.map((c) => c.city),
      datasets: [
        {
          label: "Avg India AQI",
          data: subset.map((c) => c.avg_india_aqi),
          backgroundColor: subset.map((c) => getAqiColor(c.avg_india_aqi)),
          borderRadius: 4,
        },
      ],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: "#94a3b8" }, grid: { color: "#334155" } },
        y: { ticks: { color: "#f8fafc" }, grid: { display: false } },
      },
    },
  });
}

async function loadTrends(city) {
  const res = await fetch(`/api/trends?city=${encodeURIComponent(city)}`);
  const { kpis, monthly, categories } = await res.json();

  // Update KPIs
  document.getElementById("kpiAqi").textContent = kpis.avg_aqi;
  const badge = document.getElementById("kpiAqiBadge");
  badge.textContent = getAqiLabel(kpis.avg_aqi);
  badge.style.background = getAqiColor(kpis.avg_aqi);

  document.getElementById("kpiPm25").textContent = `${kpis.avg_pm25} µg/m³`;
  document.getElementById("kpiClean").textContent = `${kpis.pct_clean_days}%`;
  document.getElementById("kpiRecords").textContent = kpis.total_records.toLocaleString();

  const labelScope = city === "ALL" ? "All India" : city;
  document.getElementById("trendTitle").textContent = `Monthly PM2.5 vs. Wind Speed (${labelScope})`;
  document.getElementById("categoryTitle").textContent = `CPCB Category Share (${labelScope})`;

  // Dual-Axis Trend Chart
  if (trendChart) trendChart.destroy();
  trendChart = new Chart(document.getElementById("trendChart"), {
    data: {
      labels: monthly.map((m) => m.month_name),
      datasets: [
        {
          type: "bar",
          label: "Avg PM2.5 (µg/m³)",
          data: monthly.map((m) => m.avg_pm25),
          backgroundColor: "rgba(56, 189, 248, 0.65)",
          yAxisID: "y",
          borderRadius: 4,
        },
        {
          type: "line",
          label: "Max Wind Speed (km/h)",
          data: monthly.map((m) => m.avg_wind),
          borderColor: "#f97316",
          backgroundColor: "#f97316",
          tension: 0.35,
          yAxisID: "y1",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: "#f8fafc" } } },
      scales: {
        x: { ticks: { color: "#94a3b8" }, grid: { display: false } },
        y: {
          position: "left",
          title: { display: true, text: "PM2.5 (µg/m³)", color: "#38bdf8" },
          ticks: { color: "#94a3b8" },
          grid: { color: "#334155" },
        },
        y1: {
          position: "right",
          title: { display: true, text: "Wind Speed (km/h)", color: "#f97316" },
          ticks: { color: "#94a3b8" },
          grid: { drawOnChartArea: false },
        },
      },
    },
  });

  // Doughnut Category Chart
  const order = ["Good", "Satisfactory", "Moderate", "Poor", "Very Poor", "Severe"];
  const orderedCats = order
    .map((cat) => categories.find((c) => c.category === cat))
    .filter(Boolean);

  if (categoryChart) categoryChart.destroy();
  categoryChart = new Chart(document.getElementById("categoryChart"), {
    type: "doughnut",
    data: {
      labels: orderedCats.map((c) => c.category),
      datasets: [
        {
          data: orderedCats.map((c) => c.days_count),
          backgroundColor: orderedCats.map((c) => CPCB_COLORS[c.category] || "#64748b"),
          borderColor: "#1e293b",
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "right", labels: { color: "#f8fafc" } },
      },
    },
  });
}

init();