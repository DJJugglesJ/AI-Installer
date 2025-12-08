const actionsList = document.getElementById("actions-list");
const actionResult = document.getElementById("action-result");
const statusPill = document.getElementById("status-pill");
const modelList = document.getElementById("model-list");
const loraList = document.getElementById("lora-list");
const characterList = document.getElementById("character-list");
const characterTableBody = document.querySelector("#character-table tbody");
const promptResult = document.getElementById("prompt-result");

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
  const response = await fetch(path, options);
  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with ${response.status}`);
  }
  return response.json();
}

function renderActions(actions) {
  actionsList.innerHTML = "";
  actions.forEach((action) => {
    const button = document.createElement("button");
    button.className = "action-button";
    button.innerHTML = `<h3>${action.label}</h3><p>${action.description}</p>`;
    button.addEventListener("click", () => triggerAction(action.id));
    actionsList.appendChild(button);
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

function renderManifestList(element, manifest) {
  element.innerHTML = "";
  manifest.items.forEach((item) => {
    const li = document.createElement("li");
    li.innerHTML = `<strong>${item.name}</strong><span>${item.version || ""}</span><span>${formatBytes(item.size_bytes)}</span><span class="tagline">${item.tags ? item.tags.join(", ") : ""}</span>`;
    element.appendChild(li);
  });
}

function renderCharacters(characters) {
  characterList.innerHTML = "";
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

async function bootstrap() {
  try {
    const status = await fetchJson("/api/status");
    statusPill.textContent = `Ready • ${status.actions.length} actions`;
    renderActions(status.actions);

    const manifests = await fetchJson("/api/manifests");
    renderManifestList(modelList, manifests.models);
    renderManifestList(loraList, manifests.loras);

    const characters = await fetchJson("/api/characters");
    renderCharacters(characters.items || []);
  } catch (err) {
    statusPill.textContent = `API error`; // surface details below
    actionResult.textContent = `Failed to load status: ${err.message}`;
  }
}

bootstrap();
addCharacterRow();

document.getElementById("add-character").addEventListener("click", () => addCharacterRow({ slot_id: `slot-${Date.now()}` }));
document.getElementById("compile-prompt").addEventListener("click", compilePrompt);
