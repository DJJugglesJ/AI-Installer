const actionsList = document.getElementById("actions-list");
const actionResult = document.getElementById("action-result");
const statusPill = document.getElementById("status-pill");
const authForm = document.getElementById("auth-form");
const authTokenInput = document.getElementById("auth-token");
const authState = document.getElementById("auth-state");
const manifestTable = document.getElementById("manifest-table");
const manifestDetail = document.getElementById("manifest-detail");
const manifestSearch = document.getElementById("manifest-search");
const filterModels = document.getElementById("filter-models");
const filterLoras = document.getElementById("filter-loras");
const tagFilters = document.getElementById("tag-filters");
const installButton = document.getElementById("install-selected");
const installResult = document.getElementById("install-result");
const pairingState = document.getElementById("pairing-state");
const pairResult = document.getElementById("pair-result");
const pairButton = document.getElementById("pair-selection");
const installProgress = document.getElementById("install-progress");
const characterList = document.getElementById("character-list");
const characterSearch = document.getElementById("character-search");
const characterTableBody = document.querySelector("#character-table tbody");
const promptResult = document.getElementById("prompt-result");
const promptHistory = document.getElementById("prompt-history");
const promptHistoryRefresh = document.getElementById("refresh-prompt-history");
const quickPromptForm = document.getElementById("quick-prompt-form");
const quickPromptResult = document.getElementById("quick-prompt-result");
const audioTools = document.getElementById("audio-tools");
const videoTools = document.getElementById("video-tools");
const ttsForm = document.getElementById("tts-form");
const asrForm = document.getElementById("asr-form");
const img2vidForm = document.getElementById("img2vid-form");
const txt2vidForm = document.getElementById("txt2vid-form");
const ttsResult = document.getElementById("tts-result");
const asrResult = document.getElementById("asr-result");
const img2vidResult = document.getElementById("img2vid-result");
const txt2vidResult = document.getElementById("txt2vid-result");
const taskList = document.getElementById("task-list");
const gpuDiagnosticsBody = document.getElementById("gpu-diagnostics-body");
const gpuRefresh = document.getElementById("refresh-gpu");
const gpuGuidance = document.getElementById("gpu-guidance");
const characterEditor = document.getElementById("character-editor");
const characterEditorResult = document.getElementById("character-editor-result");
const characterStudioLink = document.getElementById("character-studio-link");
const characterStudioSection = document.getElementById("characters");

let manifestItems = [];
const selectedModels = new Set();
const selectedLoras = new Set();
const activeTags = new Set();
let authToken = localStorage.getItem("aihubAuthToken") || "";
let characterItems = [];

function setPanelLoading(container, message) {
  container.innerHTML = `<div class="placeholder"><span class="spinner" aria-hidden="true"></span> ${message}</div>`;
}

function setPanelError(container, message, retryHandler) {
  container.innerHTML = "";
  const banner = document.createElement("div");
  banner.className = "banner error";

  const title = document.createElement("strong");
  title.textContent = "API error";
  banner.appendChild(title);

  const text = document.createElement("span");
  text.textContent = message;
  banner.appendChild(text);

  if (retryHandler) {
    const retry = document.createElement("button");
    retry.type = "button";
    retry.textContent = "Retry";
    retry.addEventListener("click", retryHandler);
    banner.appendChild(retry);
  }

  container.appendChild(banner);
}

function renderGpuDiagnostics(payload) {
  if (!gpuDiagnosticsBody) return;
  gpuDiagnosticsBody.innerHTML = "";
  if (gpuGuidance) gpuGuidance.innerHTML = "";

  const summary = payload.summary || {};
  const gpus = payload.gpus || [];
  const backend = summary.backends || {};
  const toolkits = summary.toolkits || {};
  const cpuFallback = summary.cpu_fallback || {};

  const summaryRow = document.createElement("div");
  summaryRow.className = "gpu-summary";
  summaryRow.innerHTML = `
    <strong>${summary.platform || "unknown"}</strong>
    <span class="tagline">Backends → ROCm: ${backend.rocm ? "ready" : "inactive"} • oneAPI: ${
      backend.oneapi ? "ready" : "inactive"
    } • DirectML: ${backend.directml ? "available" : "inactive"}</span>
  `;
  gpuDiagnosticsBody.appendChild(summaryRow);

  const toolkitRow = document.createElement("div");
  toolkitRow.className = "toolkit-row";
  const toolkitEntries = Object.entries(toolkits);
  if (toolkitEntries.length) {
    toolkitEntries.forEach(([name, data]) => {
      const meta = data || {};
      const badge = document.createElement("span");
      badge.className = `badge ${meta.detected ? "ok" : "warn"}`;
      const version = meta.version ? ` (v${meta.version})` : "";
      badge.textContent = `${name.toUpperCase()}: ${meta.detected ? "present" : "missing"}${version}`;
      toolkitRow.appendChild(badge);
    });
    gpuDiagnosticsBody.appendChild(toolkitRow);
  }

  if (!gpus.length) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = "No GPUs were reported by the diagnostics helper.";
    gpuDiagnosticsBody.appendChild(empty);
    if (cpuFallback && cpuFallback.reason) {
      const reason = document.createElement("p");
      reason.className = "muted";
      reason.textContent = cpuFallback.reason;
      gpuDiagnosticsBody.appendChild(reason);
    }
    return;
  }

  const list = document.createElement("ul");
  list.className = "manifest-list";

  gpus.forEach((gpu) => {
    const item = document.createElement("li");
    const memLabel = gpu.memory_mb ? `${gpu.memory_mb} MB VRAM` : "VRAM unknown";
    const driver = gpu.driver ? ` • Driver ${gpu.driver}` : "";
    const backendNotes = [];
    const hints = gpu.backend_hints || {};
    if (hints.rocm) backendNotes.push("ROCm");
    if (hints.oneapi) backendNotes.push("oneAPI");
    if (hints.directml) backendNotes.push("DirectML");
    const warnings = Array.isArray(gpu.warnings) ? gpu.warnings : [];
    item.innerHTML = `
      <strong>${gpu.vendor || "GPU"} — ${gpu.name || "Unknown"}</strong>
      <span>${memLabel}${driver}</span>
      <span class="tagline">Backends: ${backendNotes.join(", ") || "None detected"}</span>
      ${warnings.length ? `<span class="warning">${warnings.join("; ")}</span>` : ""}
    `;
    list.appendChild(item);
  });

  gpuDiagnosticsBody.appendChild(list);

  const guidance = [];
  if (cpuFallback && cpuFallback.reason) guidance.push(cpuFallback.reason);
  (summary.notes || []).forEach((note) => guidance.push(note));
  Object.values(toolkits).forEach((meta) => {
    if (!meta || !Array.isArray(meta.notes)) return;
    meta.notes.forEach((note) => guidance.push(note));
  });

  if (gpuGuidance && guidance.length) {
    const listEl = document.createElement("ul");
    listEl.className = "note-list";
    guidance.forEach((note) => {
      const li = document.createElement("li");
      li.textContent = note;
      listEl.appendChild(li);
    });
    gpuGuidance.appendChild(listEl);
  }
}

async function loadGpuDiagnostics(initial = false) {
  if (!gpuDiagnosticsBody) return;
  if (initial) {
    setPanelLoading(gpuDiagnosticsBody, "Loading GPU diagnostics…");
  }
  try {
    const diagnostics = await fetchJson("/api/hardware/gpu");
    renderGpuDiagnostics(diagnostics);
  } catch (err) {
    setPanelError(gpuDiagnosticsBody, `Failed to load GPU diagnostics: ${err.message}`, loadGpuDiagnostics);
  }
}

function setAuthToken(value) {
  authToken = value.trim();
  localStorage.setItem("aihubAuthToken", authToken);
  authState.textContent = authToken ? "Token saved" : "Not set";
}

function initAuthForm() {
  authTokenInput.value = authToken;
  authState.textContent = authToken ? "Token saved" : "Not set";
  authForm.addEventListener("submit", (event) => {
    event.preventDefault();
    setAuthToken(authTokenInput.value || "");
  });
}

function formatBytes(value) {
  if (!value && value !== 0) return "";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let idx = 0;
  let current = value;
  while (current >= 1024 && idx < units.length - 1) {
    current /= 1024;
    idx++;
  }
  return `${current.toFixed(1)} ${units[idx]}`;
}

async function fetchJson(path, options = {}) {
  const config = { ...options };
  config.headers = { ...(options.headers || {}) };
  if (authToken) {
    config.headers["Authorization"] = `Bearer ${authToken}`;
  }

  const response = await fetch(path, config);
  if (!response.ok) {
    const bodyText = await response.text();
    let payload = null;
    if (bodyText) {
      try {
        payload = JSON.parse(bodyText);
      } catch (err) {
        payload = null;
      }
    }
    const reason =
      response.status === 401 ? "Unauthorized: set the API token above." : `Request failed with ${response.status}`;
    const message = (payload && payload.error) || bodyText || reason;
    const error = new Error(message || reason);
    if (payload && payload.details) {
      error.details = payload.details;
    }
    throw error;
  }
  return response.json();
}

function escapeHtml(value) {
  if (value === undefined || value === null) return "";
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function summarizeDetail(detail) {
  if (detail === undefined || detail === null) return "";
  if (typeof detail === "object") {
    const entries = Object.entries(detail || {});
    if (!entries.length) return "";
    return entries
      .map(([key, value]) => `${key}: ${value}`)
      .join(" • ");
  }
  return String(detail);
}

function renderEventList(events = []) {
  if (!events.length) {
    return '<p class="muted">No structured status yet.</p>';
  }

  return `
    <ul class="event-list">
      ${events
        .slice(-8)
        .map((event) => {
          const detail = summarizeDetail(event.detail);
          const detailText = detail ? ` — ${escapeHtml(detail)}` : "";
          return `
            <li class="${event.level || ""}">
              <span class="stamp">${escapeHtml(event.timestamp || "")}</span>
              <span>
                <span class="event-title">${escapeHtml(event.event || "event")}</span>
                <span class="muted">${escapeHtml(event.message || "")}${detailText}</span>
              </span>
            </li>
          `;
        })
        .join("")}
    </ul>
  `;
}

function summarizeDownloadStatus(events = [], lastError = null, lastMirror = null) {
  const reversed = [...events].reverse();
  const mirrorEvent = lastMirror || reversed.find((ev) => ev.event === "mirror_selected");
  const resumeEvent = reversed.find((ev) => ev.event === "resume");
  const offlineEvent = reversed.find((ev) => ev.event === "offline_used");
  const retryCount = events.filter((ev) => ev.event === "retry").length;
  const fallbackCount = events.filter((ev) => ev.event === "mirror_fallback").length;

  const parts = [];
  if (mirrorEvent) {
    const detail = mirrorEvent.detail || {};
    const label = detail.label || detail.url || mirrorEvent.message || "mirror";
    const url = detail.url || "";
    parts.push(`Mirror: ${label}${url ? ` (${url})` : ""}`);
  }

  if (offlineEvent) parts.push("Used offline bundle");

  if (resumeEvent) {
    const bytesPresent = (resumeEvent.detail && resumeEvent.detail.bytes_present) || 0;
    parts.push(`Resumed download (${bytesPresent} bytes already present)`);
  }

  if (fallbackCount) parts.push(`Mirror fallbacks: ${fallbackCount}`);
  if (retryCount) parts.push(`Retries: ${retryCount}`);

  if (lastError) {
    const lastDetail = summarizeDetail(lastError.detail) || lastError.message || lastError.event || "download error";
    parts.push(`Last error: ${lastDetail}`);
  }

  return parts.join(" • ");
}

function renderActions(actions) {
  actionsList.innerHTML = "";
  if (!actions.length) {
    actionsList.innerHTML = '<p class="muted">No actions available.</p>';
    return;
  }

  actions.forEach((action) => {
    const button = document.createElement("button");
    button.className = "action-button";
    button.innerHTML = `<h3>${action.label}</h3><p>${action.description}</p>`;
    button.addEventListener("click", () => triggerAction(action.id));
    actionsList.appendChild(button);
  });
}

function renderTools(container, tools, label) {
  container.innerHTML = "";
  const scoped = tools.filter((tool) => !label || tool.kind === label);
  if (!scoped.length) {
    container.innerHTML = '<li class="muted">No tools available.</li>';
    return;
  }

  scoped.forEach((tool) => {
    const row = document.createElement("li");
    row.innerHTML = `<strong>${tool.label}</strong><span>${tool.description}</span><span class="tagline">${tool.available ? "Available" : "Unavailable"}</span>`;
    if (!tool.available) {
      row.classList.add("error-text");
      row.title = tool.availability_error || "Unavailable";
    }
    container.appendChild(row);
  });
}

async function triggerAction(actionId) {
  actionResult.textContent = "Running action…";
  try {
    const result = await fetchJson("/api/actions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: actionId }),
    });
    actionResult.textContent = `Started ${result.action} (pid ${result.pid}). Logs: ${result.log_path}`;
  } catch (err) {
    actionResult.textContent = `Failed to run action: ${err.message}`;
  }
}

function renderCharacters(characters) {
  const filtered = filterCharacters(characters, characterSearch ? characterSearch.value : "");
  characterList.innerHTML = "";
  if (!filtered.length) {
    characterList.innerHTML = '<li class="muted">No characters found.</li>';
    return;
  }

  filtered.forEach((card) => {
    const li = document.createElement("li");
    const nsfw = card.nsfw_allowed ? "NSFW allowed" : "SFW";
    const triggers = (card.trigger_tokens || []).join(", ") || card.trigger_token || "none";
    li.innerHTML = `<strong>${card.name}</strong><span>${card.id}</span><span class="tagline">${nsfw} • ${card.anatomy_tags.join(
      ", "
    )}</span><span class="tagline">Triggers: ${triggers}</span><button class="secondary" type="button">Edit</button>`;
    li.querySelector("button").addEventListener("click", () => fillCharacterEditor(card));
    characterList.appendChild(li);
  });
}

function addCharacterRow(data = {}) {
  const row = document.createElement("tr");
  row.innerHTML = `
    <td><input name="slot_id" value="${data.slot_id || "slot-1"}" /></td>
    <td><input name="character_id" value="${data.character_id || ""}" /></td>
    <td><input name="role" value="${data.role || ""}" /></td>
    <td><input name="override_prompt_snippet" value="${data.override_prompt_snippet || ""}" /></td>
    <td><button class="secondary" type="button">Remove</button></td>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  characterTableBody.appendChild(row);
}

function filterCharacters(cards, query) {
  const search = (query || "").trim().toLowerCase();
  if (!search) return cards;
  return cards.filter((card) => {
    const haystack = [
      card.name,
      card.id,
      card.description,
      card.trigger_token,
      ...(card.trigger_tokens || []),
      ...(card.anatomy_tags || []),
      ...(card.wardrobe || []),
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    return haystack.includes(search);
  });
}

function clearFieldErrors(form) {
  if (!form) return;
  form.querySelectorAll(".field-error").forEach((node) => node.remove());
}

function appendFieldError(input, message) {
  if (!input) return;
  const label = input.closest("label");
  if (!label) return;
  const error = document.createElement("span");
  error.className = "field-error";
  error.textContent = message;
  label.appendChild(error);
}

function splitCharacterErrors(errors = []) {
  const fieldErrors = {};
  const bannerErrors = [];
  const fieldNames = [
    "id",
    "name",
    "age",
    "nsfw_allowed",
    "description",
    "default_prompt_snippet",
    "trigger_token",
    "trigger_tokens",
    "anatomy_tags",
    "wardrobe",
    "reference_images",
    "lora_file",
    "lora_default_strength",
  ];

  errors.forEach((message) => {
    const normalized = String(message || "");
    const lower = normalized.toLowerCase();
    const field = fieldNames.find((name) =>
      new RegExp(`(^|\\W)${name.split("_").join("[_ ]")}(\\W|$)`).test(lower),
    );
    if (field) {
      fieldErrors[field] = fieldErrors[field] || [];
      fieldErrors[field].push(normalized);
    } else if (normalized) {
      bannerErrors.push(normalized);
    }
  });

  return { fieldErrors, bannerErrors };
}

function renderCharacterError(resultEl, form, err) {
  clearFieldErrors(form);
  const details = err && err.details ? err.details : {};
  const errors = Array.isArray(details.errors) && details.errors.length ? details.errors : [err.message];
  const { fieldErrors, bannerErrors } = splitCharacterErrors(errors);

  Object.entries(fieldErrors).forEach(([field, messages]) => {
    const input = form.querySelector(`[name="${field}"]`);
    if (!input) return;
    appendFieldError(input, messages.join(" "));
  });

  const bannerMessages = bannerErrors.length ? bannerErrors : [];
  const resultMessage =
    bannerMessages.length || Object.keys(fieldErrors).length
      ? "Please review the highlighted fields."
      : err.message || "Failed to save character.";
  const banner = document.createElement("div");
  banner.className = "banner error";
  banner.innerHTML = `<strong>Save failed</strong><span>${escapeHtml(resultMessage)}</span>`;
  if (bannerMessages.length) {
    const list = document.createElement("ul");
    list.className = "note-list";
    bannerMessages.forEach((message) => {
      const item = document.createElement("li");
      item.textContent = message;
      list.appendChild(item);
    });
    banner.appendChild(list);
  }
  resultEl.innerHTML = "";
  resultEl.appendChild(banner);
}

function renderResultBanner(container, type, title, message, details) {
  if (!container) return;
  container.innerHTML = "";
  const banner = document.createElement("div");
  banner.className = `banner ${type === "error" ? "error" : "success"}`;
  banner.innerHTML = `<strong>${escapeHtml(title)}</strong><span>${escapeHtml(message)}</span>`;
  if (details) {
    const detailText = summarizeDetail(details);
    if (detailText) {
      const detail = document.createElement("p");
      detail.className = "muted";
      detail.textContent = detailText;
      banner.appendChild(detail);
    }
  }
  container.appendChild(banner);
}

async function compilePrompt() {
  promptResult.textContent = "Compiling scene…";
  const form = document.getElementById("prompt-form");
  const formData = new FormData(form);
  const scene = Object.fromEntries(formData.entries());
  scene.extra_elements = (scene.extra_elements || "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);

  const characterRows = Array.from(characterTableBody.querySelectorAll("tr"));
  scene.characters = characterRows
    .map((row) => {
      const inputs = row.querySelectorAll("input");
      const payload = {};
      inputs.forEach((input) => (payload[input.name] = input.value));
      return payload;
    })
    .filter((entry) => entry.slot_id && entry.character_id);

  try {
    const result = await fetchJson("/api/prompt/guided", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ scene }),
    });
    const assembly = result.assembly;
    promptResult.innerHTML = `<div><strong>Positive:</strong> ${assembly.positive_prompt.join("; ")}</div><div><strong>Negative:</strong> ${assembly.negative_prompt.join("; ")}</div><div><strong>LoRAs:</strong> ${assembly.lora_calls.map((l) => `${l.name} (${l.weight || 1})`).join(", ") || "none"}</div><div class="tagline">Bundle saved to ${result.published.bundle_path}</div>`;
    await refreshPromptHistory();
  } catch (err) {
    promptResult.textContent = `Failed to compile prompt: ${err.message}`;
  }
}

function parseListField(value) {
  if (!value) return [];
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function buildCharacterPayload(formData) {
  return {
    id: formData.get("id"),
    name: formData.get("name"),
    age: formData.get("age") || undefined,
    nsfw_allowed: formData.get("nsfw_allowed") === "on",
    description: formData.get("description") || undefined,
    default_prompt_snippet: formData.get("default_prompt_snippet") || undefined,
    trigger_tokens: parseListField(formData.get("trigger_tokens")),
    anatomy_tags: parseListField(formData.get("anatomy_tags")),
    wardrobe: parseListField(formData.get("wardrobe")),
    reference_images: parseListField(formData.get("reference_images")),
    lora_file: formData.get("lora_file") || undefined,
    lora_default_strength: formData.get("lora_default_strength")
      ? Number(formData.get("lora_default_strength"))
      : undefined,
  };
}

function fillCharacterEditor(card) {
  if (!characterEditor) return;
  characterEditor.querySelector("[name=id]").value = card.id || "";
  characterEditor.querySelector("[name=name]").value = card.name || "";
  characterEditor.querySelector("[name=age]").value = card.age || "";
  characterEditor.querySelector("[name=nsfw_allowed]").checked = Boolean(card.nsfw_allowed);
  characterEditor.querySelector("[name=description]").value = card.description || "";
  characterEditor.querySelector("[name=default_prompt_snippet]").value = card.default_prompt_snippet || "";
  characterEditor.querySelector("[name=trigger_tokens]").value =
    (card.trigger_tokens || []).join(", ") || card.trigger_token || "";
  characterEditor.querySelector("[name=anatomy_tags]").value = (card.anatomy_tags || []).join(", ");
  characterEditor.querySelector("[name=wardrobe]").value = (card.wardrobe || []).join(", ");
  characterEditor.querySelector("[name=reference_images]").value = (card.reference_images || []).join(", ");
  characterEditor.querySelector("[name=lora_file]").value = card.lora_file || "";
  characterEditor.querySelector("[name=lora_default_strength]").value =
    card.lora_default_strength !== null && card.lora_default_strength !== undefined ? card.lora_default_strength : "";
}

async function submitCharacterEditor(event) {
  event.preventDefault();
  if (!characterEditor) return;
  clearFieldErrors(characterEditor);
  characterEditorResult.textContent = "Saving character card…";
  const formData = new FormData(characterEditor);
  const payload = buildCharacterPayload(formData);

  try {
    const result = await fetchJson("/api/characters", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    characterEditorResult.textContent = `Saved ${result.item.name} (${result.item.id}).`;
    await refreshCharacters();
  } catch (err) {
    renderCharacterError(characterEditorResult, characterEditor, err);
  }
}

async function submitQuickPrompt(event) {
  event.preventDefault();
  if (!quickPromptForm) return;
  quickPromptResult.textContent = "Compiling quick prompt…";
  const formData = new FormData(quickPromptForm);
  const payload = {
    prompt: formData.get("prompt"),
    world: formData.get("world") || undefined,
    setting: formData.get("setting") || undefined,
    mood: formData.get("mood") || undefined,
    style: formData.get("style") || undefined,
    camera: formData.get("camera") || undefined,
    nsfw_level: formData.get("nsfw_level") || undefined,
    character_ids: parseListField(formData.get("character_ids")),
    extra_elements: parseListField(formData.get("extra_elements")),
  };

  try {
    const result = await fetchJson("/api/prompt/quick", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const assembly = result.assembly;
    quickPromptResult.innerHTML = `<div><strong>Positive:</strong> ${assembly.positive_prompt.join("; ")}</div><div><strong>Negative:</strong> ${assembly.negative_prompt.join(
      "; "
    )}</div><div><strong>LoRAs:</strong> ${assembly.lora_calls.map((l) => `${l.name} (${l.weight || 1})`).join(", ") ||
      "none"}</div><div class="tagline">Bundle saved to ${result.published.bundle_path}</div>`;
    await refreshPromptHistory();
  } catch (err) {
    quickPromptResult.textContent = `Failed to compile prompt: ${err.message}`;
  }
}

function renderPromptHistory(payload) {
  if (!promptHistory) return;
  const items = payload.items || [];
  promptHistory.innerHTML = "";
  if (!items.length) {
    promptHistory.innerHTML = '<div class="muted">No prompt history yet.</div>';
    return;
  }

  items.forEach((entry) => {
    const li = document.createElement("div");
    li.className = "history-card";
    const assembly = entry.assembly || {};
    const loras = (assembly.lora_calls || []).map((l) => l.name).join(", ") || "none";
    li.innerHTML = `
      <strong>${entry.created_at}</strong>
      <span class="tagline">${assembly.positive_prompt_text || "No positive prompt text"}</span>
      <span class="tagline">LoRAs: ${loras}</span>
      <div class="history-actions">
        <button type="button" class="secondary">${entry.favorite ? "Unfavorite" : "Favorite"}</button>
      </div>
    `;
    li.querySelector("button").addEventListener("click", () =>
      togglePromptFavorite(entry.id, !entry.favorite)
    );
    promptHistory.appendChild(li);
  });
}

async function togglePromptFavorite(entryId, favorite) {
  try {
    await fetchJson("/api/prompt/history/favorite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ entry_id: entryId, favorite }),
    });
    await refreshPromptHistory();
  } catch (err) {
    console.error("Failed to toggle favorite", err);
  }
}

async function refreshPromptHistory(initial = false) {
  if (!promptHistory) return;
  if (initial) {
    setPanelLoading(promptHistory, "Loading prompt history…");
  }
  try {
    const payload = await fetchJson("/api/prompt/history");
    renderPromptHistory(payload);
  } catch (err) {
    setPanelError(promptHistory, `Failed to load prompt history: ${err.message}`, refreshPromptHistory);
  }
}

async function submitTask(toolId, payload, target) {
  target.textContent = "Submitting task…";
  try {
    const response = await fetchJson("/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tool: toolId, payload }),
    });
    const task = response.task || {};
    target.textContent = `${toolId} → ${task.status || "queued"} (${task.id || ""})`;
    await refreshTasks();
  } catch (err) {
    target.textContent = `Failed to create task: ${err.message}`;
  }
}

function renderTasks(tasks) {
  taskList.innerHTML = "";
  if (!tasks.length) {
    taskList.innerHTML = '<li class="muted">No tasks created yet.</li>';
    return;
  }
  tasks.forEach((task) => {
    const li = document.createElement("li");
    const status = task.status || "pending";
    const result = task.result || {};
    const summary = result.audio_path || result.video_path || result.transcript || "Ready";
    li.innerHTML = `<strong>${task.kind}</strong><span>${status}</span><span class="tagline">${summary}</span>`;
    taskList.appendChild(li);
  });
}

async function refreshTasks(initial = false) {
  if (!taskList) return;
  if (initial) {
    setPanelLoading(taskList, "Waiting for tasks…");
  }
  try {
    const payload = await fetchJson("/api/tasks");
    renderTasks(payload.items || []);
  } catch (err) {
    setPanelError(taskList, `Failed to load tasks: ${err.message}`);
  }
}

async function refreshCharacters() {
  try {
    const characters = await fetchJson("/api/characters");
    characterItems = characters.items || [];
    renderCharacters(characterItems);
  } catch (err) {
    setPanelError(characterList, `Failed to load characters: ${err.message}`, refreshCharacters);
  }
}

function hydrateTools(toolsPayload) {
  if (!toolsPayload) {
    return;
  }
  const items = toolsPayload.items || [];
  if (audioTools) {
    renderTools(audioTools, items.filter((tool) => tool.kind === "audio"));
  }
  if (videoTools) {
    renderTools(videoTools, items.filter((tool) => tool.kind === "video"));
  }
}

function bindLabForms() {
  if (ttsForm) {
    ttsForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(ttsForm);
      const payload = { text: formData.get("text") || "", voice: formData.get("voice") || undefined };
      const metadataRaw = formData.get("metadata");
      if (metadataRaw) {
        try {
          payload.metadata = JSON.parse(metadataRaw);
        } catch (err) {
          ttsResult.textContent = `Metadata must be valid JSON: ${err.message}`;
          return;
        }
      }
      if (!payload.text) {
        ttsResult.textContent = "Text is required.";
        return;
      }
      await submitTask("tts", payload, ttsResult);
    });
  }

  if (asrForm) {
    asrForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(asrForm);
      const payload = { source_path: formData.get("source_path"), language: formData.get("language") || undefined };
      if (!payload.source_path) {
        asrResult.textContent = "Source path is required.";
        return;
      }
      await submitTask("asr", payload, asrResult);
    });
  }

  if (img2vidForm) {
    img2vidForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(img2vidForm);
      const payload = {
        image_path: formData.get("image_path"),
        prompt: formData.get("prompt") || undefined,
        frames: Number(formData.get("frames") || 16),
      };
      if (!payload.image_path) {
        img2vidResult.textContent = "Image path is required.";
        return;
      }
      await submitTask("img2vid", payload, img2vidResult);
    });
  }

  if (txt2vidForm) {
    txt2vidForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(txt2vidForm);
      const payload = { prompt: formData.get("prompt"), duration: Number(formData.get("duration") || 4) };
      if (!payload.prompt) {
        txt2vidResult.textContent = "Prompt is required.";
        return;
      }
      await submitTask("txt2vid", payload, txt2vidResult);
    });
  }
}

async function bootstrap() {
  initAuthForm();
  bindLabForms();
  statusPill.textContent = "Loading…";
  setPanelLoading(gpuDiagnosticsBody, "Loading GPU diagnostics…");
  setPanelLoading(actionsList, "Loading actions…");
  setPanelLoading(manifestTable, "Loading manifests…");
  setPanelLoading(manifestDetail, "Select a manifest entry to see details");
  setPanelLoading(installProgress, "Loading installers…");
  setPanelLoading(characterList, "Loading characters…");
  setPanelLoading(taskList, "Loading tasks…");
  setPanelLoading(audioTools, "Loading audio tools…");
  setPanelLoading(videoTools, "Loading video tools…");
  if (promptHistory) {
    setPanelLoading(promptHistory, "Loading prompt history…");
  }

  let actionsCount = 0;
  let hasError = false;

  try {
    await loadGpuDiagnostics(true);
  } catch (err) {
    hasError = true;
  }

  try {
    const status = await fetchJson("/api/status");
    actionsCount = status.actions.length;
    renderActions(status.actions);
    hydrateTools(status.tools);
  } catch (err) {
    hasError = true;
    setPanelError(actionsList, `Failed to load actions: ${err.message}`, bootstrap);
    actionResult.textContent = "";
  }

  try {
    const manifests = await fetchJson("/api/manifests");
    hydrateManifests(manifests);
  } catch (err) {
    hasError = true;
    setPanelError(manifestTable, `Failed to load manifests: ${err.message}`, bootstrap);
  }

  try {
    await loadPairings();
  } catch (err) {
    hasError = true;
    setPanelError(manifestDetail, `Failed to load pairings: ${err.message}`, bootstrap);
  }

  try {
    await refreshCharacters();
  } catch (err) {
    hasError = true;
    setPanelError(characterList, `Failed to load characters: ${err.message}`, bootstrap);
  }

  try {
    await refreshInstallations(true);
  } catch (err) {
    hasError = true;
  }

  try {
    await refreshTasks(true);
  } catch (err) {
    hasError = true;
  }

  try {
    await refreshPromptHistory(true);
  } catch (err) {
    hasError = true;
  }

  statusPill.textContent = hasError ? "API error" : `Ready • ${actionsCount} actions`;
}

function hydrateManifests(manifests) {
  manifestItems = [
    ...(manifests.models.items || []).map((item) => ({ ...item, type: "Model" })),
    ...(manifests.loras.items || []).map((item) => ({ ...item, type: "LoRA" })),
  ];
  renderTagFilters();
  renderManifestTable();
}

function renderHealthPill(status) {
  const pill = document.createElement("span");
  pill.className = `pill inline ${status || "ok"}`;
  pill.textContent = status === "warning" ? "Needs attention" : "Healthy";
  return pill;
}

function renderManifestDetail(detail) {
  if (!manifestDetail) return;
  manifestDetail.innerHTML = "";
  if (!detail || !detail.item) {
    manifestDetail.innerHTML = '<p class="muted">No item selected.</p>';
    return;
  }

  const item = detail.item;
  const header = document.createElement("div");
  header.className = "detail-header";
  const title = document.createElement("div");
  title.innerHTML = `<strong>${item.name}</strong><span class="muted">${detail.type || ""}</span>`;
  header.appendChild(title);
  header.appendChild(renderHealthPill(item.health));
  manifestDetail.appendChild(header);

  const meta = document.createElement("div");
  meta.className = "detail-grid";
  meta.innerHTML = `
    <div><span class="muted">Version</span><strong>${item.version || ""}</strong></div>
    <div><span class="muted">License</span><strong>${item.license || ""}</strong></div>
    <div><span class="muted">Size</span><strong>${formatBytes(item.size_bytes)}</strong></div>
    <div><span class="muted">Checksum</span><strong class="wrap">${item.checksum || "—"}</strong></div>
  `;
  manifestDetail.appendChild(meta);

  const tags = document.createElement("div");
  tags.className = "tags";
  (item.tags || []).forEach((tag) => {
    const pill = document.createElement("span");
    pill.className = "tag muted";
    pill.textContent = tag;
    tags.appendChild(pill);
  });
  manifestDetail.appendChild(tags);

  const notes = document.createElement("p");
  notes.className = "muted wrap";
  notes.textContent = item.notes || "";
  manifestDetail.appendChild(notes);

  if (detail.errors && detail.errors.length) {
    const warning = document.createElement("div");
    warning.className = "banner error";
    warning.innerHTML = `<strong>Validation</strong><span>${detail.errors.join("; ")}</span>`;
    manifestDetail.appendChild(warning);
  }
}

async function loadManifestDetail(item) {
  if (!manifestDetail) return;
  setPanelLoading(manifestDetail, "Loading manifest detail…");
  try {
    const type = item.type === "Model" ? "models" : "loras";
    const detail = await fetchJson(`/api/manifests/${type}/${encodeURIComponent(item.slug || item.name)}`);
    renderManifestDetail(detail);
  } catch (err) {
    setPanelError(manifestDetail, `Failed to load manifest detail: ${err.message}`, () => loadManifestDetail(item));
  }
}

async function loadPairings() {
  if (!pairingState) return;
  setPanelLoading(pairingState, "Loading saved pairings…");
  try {
    const payload = await fetchJson("/api/pairings");
    const selection = payload.selection || {};
    pairingState.innerHTML = `
      <p class="muted">Persisted selection in installer config</p>
      <p><strong>Model:</strong> ${selection.model || "—"}</p>
      <p><strong>LoRAs:</strong> ${(selection.loras || []).join(", ") || "—"}</p>
    `;
  } catch (err) {
    setPanelError(pairingState, `Failed to load pairings: ${err.message}`, loadPairings);
    throw err;
  }
}

function renderTagFilters() {
  const tags = new Set();
  manifestItems.forEach((item) => (item.tags || []).forEach((tag) => tags.add(tag)));
  tagFilters.innerHTML = "";
  Array.from(tags)
    .sort()
    .forEach((tag) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = activeTags.has(tag) ? "tag active" : "tag";
      button.textContent = tag;
      button.addEventListener("click", () => {
        activeTags.has(tag) ? activeTags.delete(tag) : activeTags.add(tag);
        renderTagFilters();
        renderManifestTable();
      });
      tagFilters.appendChild(button);
    });
}

function matchesFilters(item) {
  const search = manifestSearch.value.toLowerCase();
  const typeAllowed = (item.type === "Model" && filterModels.checked) || (item.type === "LoRA" && filterLoras.checked);
  const matchesTag = activeTags.size === 0 || (item.tags || []).some((tag) => activeTags.has(tag));
  const haystack = [item.name, item.version, item.license, ...(item.tags || [])]
    .join(" ")
    .toLowerCase();
  const matchesSearch = !search || haystack.includes(search);
  return typeAllowed && matchesTag && matchesSearch;
}

function renderManifestTable() {
  const filtered = manifestItems.filter((item) => matchesFilters(item));
  if (!filtered.length) {
    manifestTable.innerHTML = '<p class="muted">No manifest entries match the current filters.</p>';
    return;
  }

  const table = document.createElement("table");
  table.innerHTML = `
    <thead>
      <tr><th>Select</th><th>Type</th><th>Name</th><th>Version</th><th>Size</th><th>License</th><th>Health</th><th>Tags</th><th>Notes</th><th>Actions</th></tr>
    </thead>
    <tbody></tbody>
  `;

  const tbody = table.querySelector("tbody");
  filtered.forEach((item) => {
    const row = document.createElement("tr");
    const selected = item.type === "Model" ? selectedModels.has(item.name) : selectedLoras.has(item.name);
    row.innerHTML = `
      <td><input type="checkbox" ${selected ? "checked" : ""} /></td>
      <td>${item.type}</td>
      <td><strong>${item.name}</strong></td>
      <td>${item.version || ""}</td>
      <td>${formatBytes(item.size_bytes)}</td>
      <td>${item.license || ""}</td>
      <td></td>
      <td>${(item.tags || []).join(", ")}</td>
      <td class="wrap">${item.notes || ""}</td>
      <td><button type="button" class="secondary" data-detail>Details</button></td>
    `;

    row.querySelector("input").addEventListener("change", (event) => {
      const bucket = item.type === "Model" ? selectedModels : selectedLoras;
      event.target.checked ? bucket.add(item.name) : bucket.delete(item.name);
      renderManifestTable();
    });

    const healthCell = row.querySelectorAll("td")[6];
    healthCell.appendChild(renderHealthPill(item.health));

    row.querySelector("button[data-detail]").addEventListener("click", () => loadManifestDetail(item));

    tbody.appendChild(row);
  });

  manifestTable.innerHTML = "";
  manifestTable.appendChild(table);
}

function buildPayloadFromSelection() {
  return {
    models: Array.from(selectedModels),
    loras: Array.from(selectedLoras),
  };
}

async function installSelected() {
  const payload = buildPayloadFromSelection();
  if (!payload.models.length && !payload.loras.length) {
    installResult.textContent = "Pick at least one manifest entry to install.";
    return;
  }

  installResult.textContent = "Submitting installers…";
  try {
    const response = await fetchJson("/api/installations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    installResult.textContent = `Installers started (${response.jobs.map((j) => j.id).join(", ")}).`;
    await refreshInstallations(true);
  } catch (err) {
    installResult.textContent = `Failed to start installers: ${err.message}`;
  }
}

async function pairSelection() {
  const payload = buildPayloadFromSelection();
  if (payload.models.length > 1) {
    pairResult.textContent = "Select only one model when pairing.";
    return;
  }

  pairResult.textContent = "Saving selection…";
  try {
    const response = await fetchJson("/api/pairings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: payload.models[0] || "", loras: payload.loras }),
    });
    pairResult.textContent = `Saved pairing for ${response.selection.model || "no model"}.`;
    await loadPairings();
  } catch (err) {
    pairResult.textContent = `Failed to save pairing: ${err.message}`;
  }
}

function renderHistory(history) {
  const container = document.createElement("div");

  if (!history.length) {
    container.innerHTML = '<p class="muted">No selections recorded yet.</p>';
    return container;
  }

  const heading = document.createElement("h3");
  heading.textContent = "History";
  container.appendChild(heading);

  const list = document.createElement("div");
  list.className = "history-list";

  history.forEach((entry) => {
    const card = document.createElement("div");
    card.className = "history-card";

    const info = document.createElement("div");
    const startedAt = document.createElement("strong");
    startedAt.textContent = entry.started_at;
    info.appendChild(startedAt);

    const status = document.createElement("p");
    status.className = "muted";
    status.textContent = entry.status;
    info.appendChild(status);

    const models = document.createElement("p");
    models.textContent = `Models: ${(entry.models || []).join(", ") || "—"}`;
    info.appendChild(models);

    const loras = document.createElement("p");
    loras.textContent = `LoRAs: ${(entry.loras || []).join(", ") || "—"}`;
    info.appendChild(loras);

    const actions = document.createElement("div");
    actions.className = "history-actions";

    const reuseButton = document.createElement("button");
    reuseButton.type = "button";
    reuseButton.textContent = "Reuse";
    reuseButton.dataset.models = JSON.stringify(entry.models || []);
    reuseButton.dataset.loras = JSON.stringify(entry.loras || []);
    actions.appendChild(reuseButton);

    const logLink = document.createElement("a");
    logLink.href = `file://${entry.log_path}`;
    logLink.target = "_blank";
    logLink.rel = "noreferrer";
    logLink.textContent = "Log";
    actions.appendChild(logLink);

    card.appendChild(info);
    card.appendChild(actions);
    list.appendChild(card);
  });

  container.appendChild(list);
  return container;
}

function renderJobs(jobs) {
  if (!jobs.length) {
      return '<p class="muted">No running installers.</p>';
    }

    return jobs
      .map(
        (job) => `
          <div class="job-card">
            <div class="job-header">
              <div>
                <strong>${job.id}</strong>
                <p class="muted">${job.status}${job.returncode !== null ? ` (code ${job.returncode})` : ""}</p>
              </div>
              <span class="pill ${job.status}">${job.status}</span>
            </div>
            <p class="muted">${job.started_at}${job.completed_at ? ` → ${job.completed_at}` : ""}</p>
            <p>Models: ${(job.models || []).join(", ") || "—"}</p>
            <p>LoRAs: ${(job.loras || []).join(", ") || "—"}</p>
            <pre>${(job.log_tail || "").trim() || "(no log output yet)"}</pre>
            <div class="job-events">
              <p class="muted">Download status</p>
              ${(() => {
                const summary = summarizeDownloadStatus(job.events || [], job.last_error, job.last_mirror);
                return summary ? `<p class="muted">${escapeHtml(summary)}</p>` : "";
              })()}
              ${renderEventList(job.events || [])}
            </div>
          </div>
        `,
      )
      .join("");
  }

async function refreshInstallations(showLoading = false) {
  if (showLoading) {
    setPanelLoading(installProgress, "Loading installers…");
  }

  try {
    const installs = await fetchJson("/api/installations");
    installProgress.innerHTML = "";

    const runningContainer = document.createElement("div");
    runningContainer.innerHTML = `
      <h3>Running</h3>
      ${renderJobs((installs.jobs || []).filter((j) => j.status === "running"))}
    `;

    const historyContainer = document.createElement("div");
    historyContainer.appendChild(renderHistory(installs.history || []));

    installProgress.appendChild(runningContainer);
    installProgress.appendChild(historyContainer);

    installProgress.querySelectorAll("button[data-models]").forEach((btn) => {
      btn.addEventListener("click", () => {
        selectedModels.clear();
        selectedLoras.clear();
        JSON.parse(btn.dataset.models || "[]").forEach((name) => selectedModels.add(name));
        JSON.parse(btn.dataset.loras || "[]").forEach((name) => selectedLoras.add(name));
        installResult.textContent = "Loaded selection from history.";
        renderManifestTable();
      });
    });
  } catch (err) {
    statusPill.textContent = "API error";
    setPanelError(installProgress, `Failed to load installers: ${err.message}`, () => refreshInstallations(true));
    throw err;
  }
}

function initCharacterStudioPage() {
  const cardList = document.getElementById("cs-card-list");
  const cardDetail = document.getElementById("cs-card-detail");
  const cardForm = document.getElementById("cs-card-form");
  const cardStatus = document.getElementById("cs-card-status");
  const cardSearch = document.getElementById("cs-card-search");
  const datasetSummary = document.getElementById("cs-dataset-summary");
  const datasetForm = document.getElementById("cs-dataset-form");
  const datasetCharacter = document.getElementById("cs-dataset-character");
  const datasetSubset = document.getElementById("cs-dataset-subset");
  const datasetImages = document.getElementById("cs-dataset-images");
  const datasetExtraTags = document.getElementById("cs-dataset-extra-tags");
  const datasetTaggerCmd = document.getElementById("cs-dataset-tagger-cmd");
  const datasetInitButton = document.getElementById("cs-dataset-init");
  const datasetAddImagesButton = document.getElementById("cs-dataset-add-images");
  const datasetCaptionsButton = document.getElementById("cs-dataset-captions");
  const datasetAutoTagButton = document.getElementById("cs-dataset-auto-tag");
  const datasetResult = document.getElementById("cs-dataset-result");
  const tabButtons = document.querySelectorAll("[data-tab]");
  const tabPanels = document.querySelectorAll("[data-panel]");
  let cardItems = [];
  let activeCard = null;

  if (!cardList || !cardDetail || !cardForm) {
    return;
  }

  initAuthForm();

  const renderCardDetail = (card) => {
    if (!card) {
      cardDetail.innerHTML = '<p class="muted">Select a card to see details.</p>';
      return;
    }
    const triggers = (card.trigger_tokens || []).join(", ") || card.trigger_token || "none";
    const referenceImages = (card.reference_images || []).join(", ") || "none";
    cardDetail.innerHTML = `
      <div class="detail-header">
        <div>
          <strong>${escapeHtml(card.name || "Unnamed")}</strong>
          <span class="muted">${escapeHtml(card.id || "")}</span>
        </div>
        <span class="pill inline ${card.nsfw_allowed ? "warning" : "ok"}">${card.nsfw_allowed ? "NSFW" : "SFW"}</span>
      </div>
      <div class="detail-grid">
        <div><span class="muted">Age</span><strong>${escapeHtml(card.age || "—")}</strong></div>
        <div><span class="muted">LoRA</span><strong>${escapeHtml(card.lora_file || "—")}</strong></div>
        <div><span class="muted">Strength</span><strong>${card.lora_default_strength ?? "—"}</strong></div>
        <div><span class="muted">Tokens</span><strong>${escapeHtml(triggers)}</strong></div>
      </div>
      <p class="muted">${escapeHtml(card.description || "No description provided.")}</p>
      <p class="tagline">Anatomy: ${escapeHtml((card.anatomy_tags || []).join(", ") || "none")}</p>
      <p class="tagline">Wardrobe: ${escapeHtml((card.wardrobe || []).join(", ") || "none")}</p>
      <p class="tagline">Reference images: ${escapeHtml(referenceImages)}</p>
    `;
  };

  const setDatasetControlsEnabled = (enabled) => {
    if (datasetForm) {
      datasetForm.querySelectorAll("input, textarea, button").forEach((input) => {
        if (input.id === "cs-dataset-character") return;
        input.disabled = !enabled;
      });
    }
  };

  const renderDatasetSummary = (summary) => {
    if (!datasetSummary) return;
    datasetSummary.innerHTML = "";
    if (!summary || !summary.exists) {
      datasetSummary.innerHTML = `
        <strong>Dataset not initialized</strong>
        <p class="muted">Run the initializer to create dataset folders for this character.</p>
      `;
      if (summary && summary.dataset_root) {
        const root = document.createElement("p");
        root.className = "muted";
        root.textContent = summary.dataset_root;
        datasetSummary.appendChild(root);
      }
      return;
    }

    const header = document.createElement("div");
    header.className = "detail-header";
    header.innerHTML = `
      <div>
        <strong>Dataset status</strong>
        <span class="muted">${escapeHtml(summary.dataset_root || "")}</span>
      </div>
      <span class="pill inline ok">${summary.total_images || 0} images</span>
    `;
    datasetSummary.appendChild(header);

    const totals = document.createElement("div");
    totals.className = "detail-grid";
    totals.innerHTML = `
      <div><span class="muted">Captioned</span><strong>${summary.total_captioned || 0}</strong></div>
      <div><span class="muted">Missing captions</span><strong>${summary.total_missing_captions || 0}</strong></div>
      <div><span class="muted">Subsets</span><strong>${(summary.subsets || []).length}</strong></div>
    `;
    datasetSummary.appendChild(totals);

    const subsets = summary.subsets || [];
    if (!subsets.length) {
      const empty = document.createElement("p");
      empty.className = "muted";
      empty.textContent = "No subset folders found yet.";
      datasetSummary.appendChild(empty);
      return;
    }

    const grid = document.createElement("div");
    grid.className = "panel-grid";
    subsets.forEach((subset) => {
      const card = document.createElement("div");
      card.className = "panel-card";
      card.innerHTML = `
        <strong>${escapeHtml(subset.name || "subset")}</strong>
        <p class="muted">${escapeHtml(subset.path || "")}</p>
        <p class="tagline">${subset.image_count || 0} images • ${subset.captioned_count || 0} captioned • ${
          subset.missing_captions || 0
        } missing</p>
      `;
      grid.appendChild(card);
    });
    datasetSummary.appendChild(grid);
  };

  const refreshDatasetSummary = async (showLoading = false) => {
    if (!datasetSummary || !activeCard) return;
    if (showLoading) {
      setPanelLoading(datasetSummary, "Loading dataset status…");
    }
    try {
      const payload = await fetchJson(`/api/characters/${activeCard.id}/dataset`);
      renderDatasetSummary(payload.item);
    } catch (err) {
      setPanelError(
        datasetSummary,
        `Failed to load dataset status: ${err.message}`,
        () => refreshDatasetSummary(true),
      );
    }
  };

  const setActiveCard = (card) => {
    activeCard = card;
    renderCardDetail(card);
    if (card) {
      fillCharacterForm(card);
    }
    if (datasetCharacter) {
      datasetCharacter.value = card ? `${card.name || "Unnamed"} (${card.id})` : "";
    }
    if (!card) {
      if (datasetSummary) {
        datasetSummary.innerHTML = '<p class="muted">Select a character card to review dataset status.</p>';
      }
      setDatasetControlsEnabled(false);
      return;
    }
    setDatasetControlsEnabled(true);
    refreshDatasetSummary(true);
  };

  const parsePathList = (rawText) => {
    if (!rawText) return [];
    return rawText
      .split(/[\n,]+/)
      .map((item) => item.trim())
      .filter(Boolean);
  };

  const renderCardList = (cards) => {
    const filtered = filterCharacters(cards, cardSearch ? cardSearch.value : "");
    cardList.innerHTML = "";
    if (!filtered.length) {
      cardList.innerHTML = '<li class="muted">No cards available.</li>';
      setActiveCard(null);
      return;
    }

    filtered.forEach((card) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "cs-list-item";
      button.innerHTML = `<strong>${escapeHtml(card.name || "Unnamed")}</strong><span>${escapeHtml(
        card.id || "",
      )}</span>`;
      button.addEventListener("click", () => {
        cardList.querySelectorAll(".cs-list-item").forEach((item) => item.classList.remove("active"));
        button.classList.add("active");
        setActiveCard(card);
      });
      cardList.appendChild(button);
    });

    const first = filtered[0];
    const firstButton = cardList.querySelector(".cs-list-item");
    if (firstButton) {
      firstButton.classList.add("active");
    }
    setActiveCard(first);
  };

  const fillCharacterForm = (card) => {
    if (!card) return;
    cardForm.querySelector("[name=id]").value = card.id || "";
    cardForm.querySelector("[name=name]").value = card.name || "";
    cardForm.querySelector("[name=age]").value = card.age || "";
    cardForm.querySelector("[name=nsfw_allowed]").checked = Boolean(card.nsfw_allowed);
    cardForm.querySelector("[name=description]").value = card.description || "";
    cardForm.querySelector("[name=default_prompt_snippet]").value = card.default_prompt_snippet || "";
    cardForm.querySelector("[name=trigger_tokens]").value =
      (card.trigger_tokens || []).join(", ") || card.trigger_token || "";
    cardForm.querySelector("[name=anatomy_tags]").value = (card.anatomy_tags || []).join(", ");
    cardForm.querySelector("[name=wardrobe]").value = (card.wardrobe || []).join(", ");
    cardForm.querySelector("[name=reference_images]").value = (card.reference_images || []).join(", ");
    cardForm.querySelector("[name=lora_file]").value = card.lora_file || "";
    cardForm.querySelector("[name=lora_default_strength]").value =
      card.lora_default_strength !== null && card.lora_default_strength !== undefined ? card.lora_default_strength : "";
  };

  const refreshCards = async () => {
    setPanelLoading(cardList, "Loading character cards…");
    try {
      const payload = await fetchJson("/api/characters");
      cardItems = payload.items || [];
      renderCardList(cardItems);
    } catch (err) {
      setPanelError(cardList, `Failed to load cards: ${err.message}`, refreshCards);
    }
  };

  cardForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    clearFieldErrors(cardForm);
    cardStatus.textContent = "Saving card…";
    const formData = new FormData(cardForm);
    const payload = buildCharacterPayload(formData);
    try {
      const response = await fetchJson("/api/characters", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      cardStatus.textContent = `Saved ${response.item.name} (${response.item.id}).`;
      await refreshCards();
    } catch (err) {
      renderCharacterError(cardStatus, cardForm, err);
    }
  });

  if (datasetInitButton) {
    datasetInitButton.addEventListener("click", async () => {
      if (!activeCard) return;
      renderResultBanner(datasetResult, "success", "Dataset", "Initializing dataset…");
      try {
        const payload = await fetchJson(`/api/characters/${activeCard.id}/dataset/init`, { method: "POST" });
        renderResultBanner(datasetResult, "success", "Dataset initialized", "Folders created successfully.");
        renderDatasetSummary(payload.item);
      } catch (err) {
        renderResultBanner(datasetResult, "error", "Init failed", err.message, err.details);
      }
    });
  }

  if (datasetAddImagesButton) {
    datasetAddImagesButton.addEventListener("click", async () => {
      if (!activeCard) return;
      const subset = datasetSubset && datasetSubset.value ? datasetSubset.value.trim() : "base";
      const images = parsePathList(datasetImages ? datasetImages.value : "");
      if (!images.length) {
        renderResultBanner(datasetResult, "error", "Add images failed", "Provide at least one image path.");
        return;
      }
      renderResultBanner(datasetResult, "success", "Dataset", "Adding images…");
      try {
        const response = await fetchJson(`/api/characters/${activeCard.id}/dataset/add-images`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ subset, images }),
        });
        renderResultBanner(
          datasetResult,
          "success",
          "Images added",
          `${response.stored.length} images copied to ${subset}.`,
        );
        renderDatasetSummary(response.summary);
      } catch (err) {
        renderResultBanner(datasetResult, "error", "Add images failed", err.message, err.details);
      }
    });
  }

  if (datasetCaptionsButton) {
    datasetCaptionsButton.addEventListener("click", async () => {
      if (!activeCard) return;
      const subset = datasetSubset && datasetSubset.value ? datasetSubset.value.trim() : "base";
      renderResultBanner(datasetResult, "success", "Dataset", "Generating captions…");
      try {
        const response = await fetchJson(`/api/characters/${activeCard.id}/dataset/captions`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ subset }),
        });
        renderResultBanner(
          datasetResult,
          "success",
          "Captions generated",
          `${response.captions.length} captions written for ${subset}.`,
        );
        renderDatasetSummary(response.summary);
      } catch (err) {
        renderResultBanner(datasetResult, "error", "Captioning failed", err.message, err.details);
      }
    });
  }

  if (datasetAutoTagButton) {
    datasetAutoTagButton.addEventListener("click", async () => {
      if (!activeCard) return;
      const subset = datasetSubset && datasetSubset.value ? datasetSubset.value.trim() : "base";
      const extraTags = parsePathList(datasetExtraTags ? datasetExtraTags.value : "");
      const tagger_cmd = datasetTaggerCmd && datasetTaggerCmd.value ? datasetTaggerCmd.value.trim() : "";
      renderResultBanner(datasetResult, "success", "Dataset", "Auto-tagging images…");
      try {
        const response = await fetchJson(`/api/characters/${activeCard.id}/dataset/auto-tag`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            subset,
            extra_tags: extraTags.length ? extraTags : undefined,
            tagger_cmd: tagger_cmd || undefined,
          }),
        });
        renderResultBanner(
          datasetResult,
          "success",
          "Auto-tag complete",
          `${response.captions.length} captions updated for ${subset}.`,
        );
        renderDatasetSummary(response.summary);
      } catch (err) {
        renderResultBanner(datasetResult, "error", "Auto-tag failed", err.message, err.details);
      }
    });
  }

  tabButtons.forEach((button) => {
    button.addEventListener("click", () => {
      tabButtons.forEach((tab) => tab.classList.remove("active"));
      button.classList.add("active");
      tabPanels.forEach((panel) => {
        panel.classList.toggle("active", panel.dataset.panel === button.dataset.tab);
      });
    });
  });

  if (cardSearch) {
    cardSearch.addEventListener("input", () => renderCardList(cardItems));
  }

  refreshCards();
}

function initMainPage() {
  bootstrap();
  addCharacterRow();

  document
    .getElementById("add-character")
    .addEventListener("click", () => addCharacterRow({ slot_id: `slot-${Date.now()}` }));
  document.getElementById("compile-prompt").addEventListener("click", compilePrompt);
  if (quickPromptForm) {
    quickPromptForm.addEventListener("submit", submitQuickPrompt);
  }
  if (promptHistoryRefresh) {
    promptHistoryRefresh.addEventListener("click", () => refreshPromptHistory(true));
  }
  if (characterEditor) {
    characterEditor.addEventListener("submit", submitCharacterEditor);
  }
  if (characterSearch) {
    characterSearch.addEventListener("input", () => renderCharacters(characterItems));
  }
  manifestSearch.addEventListener("input", renderManifestTable);
  filterModels.addEventListener("change", renderManifestTable);
  filterLoras.addEventListener("change", renderManifestTable);
  installButton.addEventListener("click", installSelected);
  if (pairButton) {
    pairButton.addEventListener("click", pairSelection);
  }
  if (gpuRefresh) {
    gpuRefresh.addEventListener("click", () => loadGpuDiagnostics(true));
  }
  setInterval(() => {
    refreshInstallations().catch(() => {});
  }, 5000);
}

window.AIHub = window.AIHub || {};
window.AIHub.initCharacterStudioPage = initCharacterStudioPage;

const isMainPage = Boolean(document.getElementById("actions-list"));
if (isMainPage) {
  initMainPage();
}
