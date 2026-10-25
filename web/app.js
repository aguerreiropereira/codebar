const DEFAULT_SETTINGS = {
  widgets: {
    escape: { enabled: true, width: 54 },
    codex: { enabled: true, refresh: 30, bordered: true, url: "https://chatgpt.com" },
    claude: { enabled: true, refresh: 30, bordered: true, url: "https://claude.ai" },
    antigravity: { enabled: true, refresh: 30, bordered: true, url: "" },
    brightness: { enabled: false },
    volume: { enabled: true },
    battery: { enabled: true },
    clock: { enabled: true, format: "HH:mm" },
    settings: { enabled: true }
  },
  order: ["escape", "codex", "claude", "antigravity", "settings", "brightness", "volume", "battery", "clock"]
};

function normalizeSettings(candidate) {
  const defaults = JSON.parse(JSON.stringify(DEFAULT_SETTINGS));
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) return defaults;

  const savedWidgets = candidate.widgets && typeof candidate.widgets === "object" && !Array.isArray(candidate.widgets)
    ? candidate.widgets
    : {};
  for (const [id, defaultConfig] of Object.entries(defaults.widgets)) {
    const savedConfig = savedWidgets[id];
    if (savedConfig && typeof savedConfig === "object" && !Array.isArray(savedConfig)) {
      defaults.widgets[id] = { ...defaultConfig, ...savedConfig };
    }
  }

  const allowedIds = new Set(Object.keys(defaults.widgets));
  const savedOrder = Array.isArray(candidate.order) ? candidate.order : [];
  const validSavedOrder = [...new Set(savedOrder.filter(id => allowedIds.has(id)))];
  defaults.order = [...validSavedOrder, ...DEFAULT_SETTINGS.order.filter(id => !validSavedOrder.includes(id))];
  return defaults;
}

let state = {
  settings: normalizeSettings(),
  live: {
    codex: "--",
    claude: "--",
    antigravity: "--"
  }
};

async function init() {
  try {
    const res = await fetch("/api/settings");
    const data = await res.json();
    if (data.settings) state.settings = normalizeSettings(data.settings);
    if (data.live && typeof data.live === "object") state.live = data.live;
  } catch (e) {
    console.warn("Using default settings", e);
  }

  syncUIFromState();
  renderTouchBarPreview();

  // Poll live data every 5 seconds
  setInterval(pollLiveData, 5000);
}

function syncUIFromState() {
  const w = state.settings.widgets;
  
  setToggle("codex-enabled", w.codex?.enabled);
  setSelect("codex-refresh", w.codex?.refresh || 30);
  
  setToggle("claude-enabled", w.claude?.enabled);
  setSelect("claude-refresh", w.claude?.refresh || 30);
  
  setToggle("antigravity-enabled", w.antigravity?.enabled);
  setSelect("antigravity-refresh", w.antigravity?.refresh || 30);
  
  setToggle("escape-enabled", w.escape?.enabled);
  setToggle("settings-enabled", w.settings?.enabled);
  setToggle("volume-enabled", w.volume?.enabled);
  setToggle("battery-enabled", w.battery?.enabled);
  setToggle("clock-enabled", w.clock?.enabled);
  setToggle("brightness-enabled", w.brightness?.enabled);

  updateLiveDescriptions();
}

function setToggle(id, val) {
  const el = document.getElementById(id);
  if (el) el.checked = !!val;
}

function setSelect(id, val) {
  const el = document.getElementById(id);
  if (el) el.value = String(val);
}

function updateLiveDescriptions() {
  const cx = document.getElementById("codex-live-desc");
  if (cx) cx.textContent = `Ao vivo: ${state.live.codex || "--"}`;

  const cl = document.getElementById("claude-live-desc");
  if (cl) cl.textContent = `Ao vivo: ${state.live.claude || "--"}`;

  const ag = document.getElementById("antigravity-live-desc");
  if (ag) ag.textContent = `Ao vivo: ${state.live.antigravity || "--"}`;
}

function renderTouchBarPreview() {
  const container = document.getElementById("touchbar-preview");
  if (!container) return;

  const w = state.settings.widgets;
  const leftItems = [];
  const rightItems = [];

  // Left side
  if (w.escape?.enabled) {
    leftItems.push(`<div class="tb-btn tb-esc">esc</div>`);
  }

  if (w.codex?.enabled) {
    leftItems.push(`
      <div class="tb-btn">
        <img src="/api/icon/codex" class="tb-icon" alt="Codex">
        <span>${state.live.codex || "--"}</span>
      </div>
    `);
  }

  if (w.claude?.enabled) {
    leftItems.push(`
      <div class="tb-btn">
        <img src="/api/icon/claude" class="tb-icon" alt="Claude">
        <span>${state.live.claude || "--"}</span>
      </div>
    `);
  }

  if (w.antigravity?.enabled) {
    leftItems.push(`
      <div class="tb-btn">
        <img src="/api/icon/antigravity" class="tb-icon" alt="Antigravity">
        <span>${state.live.antigravity || "--"}</span>
      </div>
    `);
  }

  // Right side
  if (w.brightness?.enabled) {
    rightItems.push(`<div class="tb-btn tb-btn-flat">🔆</div>`);
  }
  if (w.settings?.enabled) {
    rightItems.push(`<div class="tb-btn" style="width:34px;justify-content:center;font-size:12px;">⚙️</div>`);
  }
  if (w.volume?.enabled) {
    rightItems.push(`<div class="tb-btn tb-btn-flat">🔊</div>`);
  }
  if (w.battery?.enabled) {
    rightItems.push(`<div class="tb-btn tb-btn-flat">🔋 98%</div>`);
  }
  if (w.clock?.enabled) {
    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    rightItems.push(`<div class="tb-btn tb-btn-flat" style="font-family:var(--mono);font-size:11px;">${timeStr}</div>`);
  }

  container.innerHTML = `
    <div class="tb-group-left">${leftItems.join("")}</div>
    <div class="tb-group-right">${rightItems.join("")}</div>
  `;
}

function markDirty() {
  const w = state.settings.widgets;
  
  w.codex.enabled = document.getElementById("codex-enabled").checked;
  w.codex.refresh = parseInt(document.getElementById("codex-refresh").value, 10);
  
  w.claude.enabled = document.getElementById("claude-enabled").checked;
  w.claude.refresh = parseInt(document.getElementById("claude-refresh").value, 10);
  
  w.antigravity.enabled = document.getElementById("antigravity-enabled").checked;
  w.antigravity.refresh = parseInt(document.getElementById("antigravity-refresh").value, 10);

  w.escape.enabled = document.getElementById("escape-enabled").checked;
  w.settings.enabled = document.getElementById("settings-enabled").checked;
  w.volume.enabled = document.getElementById("volume-enabled").checked;
  w.battery.enabled = document.getElementById("battery-enabled").checked;
  w.clock.enabled = document.getElementById("clock-enabled").checked;
  w.brightness.enabled = document.getElementById("brightness-enabled").checked;

  renderTouchBarPreview();
}

async function pollLiveData() {
  try {
    const res = await fetch("/api/live");
    const data = await res.json();
    state.live = data;
    updateLiveDescriptions();
    renderTouchBarPreview();
  } catch (e) {
    // quiet polling error
  }
}

async function saveConfiguration() {
  const btn = document.getElementById("save-btn");
  btn.disabled = true;
  btn.innerHTML = `<span class="btn-icon">⏳</span> Aplicando...`;

  try {
    const res = await fetch("/api/settings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.settings)
    });
    
    if (res.ok) {
      showToast("Configurações aplicadas na Touch Bar com sucesso!");
    } else {
      alert("Erro ao aplicar configurações.");
    }
  } catch (e) {
    alert("Falha ao comunicar com o servidor: " + e.message);
  } finally {
    btn.disabled = false;
    btn.innerHTML = `<span class="btn-icon">💾</span> Salvar & Aplicar`;
  }
}

function showToast(msg) {
  const toast = document.getElementById("toast");
  if (!toast) return;
  toast.textContent = msg;
  toast.classList.add("show");
  setTimeout(() => {
    toast.classList.remove("show");
  }, 3500);
}

document.addEventListener("DOMContentLoaded", init);
