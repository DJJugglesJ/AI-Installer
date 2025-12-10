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
const characterTableBody = document.querySelector("#character-table tbody");
const promptResult = document.getElementById("prompt-result");
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

let manifestItems = [];
const selectedModels = new Set();
const selectedLoras = new Set();
const activeTags = new Set();
let authToken = localStorage.getItem("aihubAuthToken") || "";

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

  const summary = payload.summary || {};
  const gpus = payload.gpus || [];
  const backend = summary.backends || {};

  const summaryRow = document.createElement("div");
  summaryRow.className = "gpu-summary";
  summaryRow.innerHTML = `
    <strong>${summary.platform || "unknown"}</strong>
    <span class="tagline">Backends → ROCm: ${backend.rocm ? "ready" : "inactive"} • oneAPI: ${
      backend.oneapi ? "ready" : "inactive"
    } • DirectML: ${backend.directml ? "available" : "inactive"}</span>
  `;
  gpuDiagnosticsBody.appendChild(summaryRow);

  if (!gpus.length) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = "No GPUs were reported by the diagnostics helper.";
    gpuDiagnosticsBody.appendChild(empty);
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
    item.innerHTML = `
      <strong>${gpu.vendor || "GPU"} — ${gpu.name || "Unknown"}</strong>
      <span>${memLabel}${driver}</span>
      <span class="tagline">Backends: ${backendNotes.join(", ") || "None detected"}</span>
    `;
    list.appendChild(item);
  });

  gpuDiagnosticsBody.appendChild(list);
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
    const message = await response.text();
    const reason =
      response.status === 401 ? "Unauthorized: set the API token above." : `Request failed with ${response.status}`;
    throw new Error(message || reason);
  }
  return response.json();
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
  characterList.innerHTML = "";
  if (!characters.length) {
    characterList.innerHTML = '<li class="muted">No characters found.</li>';
    return;
  }

  characters.forEach((card) => {
    const li = document.createElement("li");
    const nsfw = card.nsfw_allowed ? "NSFW allowed" : "SFW";
    li.innerHTML = `<strong>${card.name}</strong><span>${card.id}</span><span class="tagline">${nsfw} • ${card.anatomy_tags.join(", ")}</span>`;
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
    const result = await fetchJson("/api/prompt/compile", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ scene }),
    });
    const assembly = result.assembly;
    promptResult.innerHTML = `<div><strong>Positive:</strong> ${assembly.positive_prompt.join("; ")}</div><div><strong>Negative:</strong> ${assembly.negative_prompt.join("; ")}</div><div><strong>LoRAs:</strong> ${assembly.lora_calls.map((l) => `${l.name} (${l.weight || 1})`).join(", ") || "none"}</div><div class="tagline">Bundle saved to ${result.published.bundle_path}</div>`;
  } catch (err) {
    promptResult.textContent = `Failed to compile prompt: ${err.message}`;
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
    const characters = await fetchJson("/api/characters");
    renderCharacters(characters.items || []);
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

bootstrap();
addCharacterRow();

document.getElementById("add-character").addEventListener("click", () => addCharacterRow({ slot_id: `slot-${Date.now()}` }));
document.getElementById("compile-prompt").addEventListener("click", compilePrompt);
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
