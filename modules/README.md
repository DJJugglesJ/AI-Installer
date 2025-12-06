# AI Hub – Modules Overview

This directory contains all modular components that power AI Hub.  
It is divided into two major categories that reflect the core architectural split:

- **Runtime Modules (Python)** – high-level logic for prompt building, character management, LoRA workflows, and orchestration.
- **Shell Modules (Bash)** – low-level helper scripts used for installation, backend launching, system detection, and model management.

This document explains how the module system is organized, what each part is responsible for, and how they interact.

---

# ====================================
# 1. Runtime Modules (Python)
# ====================================
Located under:
modules/runtime/

Runtime modules implement AI Hub’s **core application logic**. These packages operate *after* installation and provide structured tools that interact with AI backends through abstraction layers.

Current runtime modules include:

### 📌 `prompt_builder/`
Responsible for generating high-quality prompts from structured scene descriptions.

Key features:
- Accepts a `SceneDescription` JSON object.
- Uses LLMs to compile:
  - positive prompt
  - negative prompt
  - LoRA call list
- Supports both simple and advanced prompt modes.
- Provides `apply_feedback_to_scene()` to refine scenes using natural language adjustments.
- Does not directly run Stable Diffusion — outputs text only.

---

### 📌 `character_studio/`
Responsible for managing character definitions and dataset workflows.

Key features:
- Creates and edits **Character Cards** with:
  - identity details
  - prompt snippets
  - tags/traits
  - optional LoRA metadata
- Generates reference images via backend abstraction.
- Prepares datasets for LoRA training:
  - captioning
  - auto-tagging
  - folder structure
- Provides `apply_feedback_to_character()` for LLM-driven refinement.
- Outputs training-ready datasets and configs.

---

### Runtime Module Design Principles

- **Backend-agnostic**  
  Modules never assume WebUI vs ComfyUI; they operate on abstraction layers.

- **JSON-driven**  
  All inputs and outputs use structured schemas.

- **Modular and safe**  
  Each module is responsible for one major workflow.

- **Extensible**  
  New modules (e.g., video builder, tagging engine, LoRA manager backend) can be added without modifying existing modules.

---

# ====================================
# 2. Shell Modules (Bash)
# ====================================
Located under:
modules/shell/


These scripts provide **OS-level operations** required by AI Hub. They are used by both the Installer Layer and Launcher Layer.

Examples include:

- GPU detection  
- System validation  
- Installing WebUI / ComfyUI / text backends  
- Running services  
- Health checks  
- Downloading and filtering models and LoRAs  

Shell scripts are used because certain tasks require direct system integration that Python is not ideal for.

### Shell Module Responsibilities

- **Installer operations**  
  - Clone repos  
  - Install dependencies  
  - Validate environment  
  - Prepare model directories  

- **Launcher operations**  
  - Start WebUI or ComfyUI  
  - Start text generation servers  
  - Provide health summaries for running services  

- **Helper operations**  
  - Logging utilities  
  - Pairing presets  
  - Filtering tools  
  - Update mechanisms  

---

# ====================================
# 3. Interaction Between Runtime and Shell Modules
# ====================================

The architecture cleanly separates roles:

- Shell modules manage **system-level setup and launching**.
- Runtime modules manage **AI workflows and orchestration logic**.

Runtime modules typically **do not** call shell scripts directly.  
Instead, shell scripts are used by:

- `install.sh`
- `aihub_menu.sh`
- Backend launchers

The Runtime Layer interacts with AI tools through **HTTP APIs**, not process control.

---

# ====================================
# 4. When to Add a New Module
# ====================================

### Add a new **runtime module** if:
- The feature is Python-based  
- It processes structured data  
- It interacts with AI backends  
- It implements an AI workflow (prompting, tagging, training)

### Add a new **shell module** if:
- The feature interacts directly with the OS  
- It installs/updates/runs external tools  
- It manages system state  
- It needs bash-level performance or utilities

---

# ====================================
# 5. Summary
# ====================================

The `modules/` directory contains the heart of AI Hub’s architecture.  
It divides responsibilities into:

- **Runtime logic (Python)** in `modules/runtime/`  
- **Installer/launcher helpers (Shell)** in `modules/shell/`

This structure keeps the application clean, scalable, and easy to maintain as new capabilities are added.

