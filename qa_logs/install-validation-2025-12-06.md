# Install validation report (2025-12-06)

## Environment
- Host: Ubuntu 24.04.3 LTS (noble)
- Kernel: 6.12.13
- Shell user: root
- Repository commit under test: a4a3cea

## Test matrix and results
| Mode | Target | Command | Result | Notes |
| ---- | ------ | ------- | ------ | ----- |
| Headless | webui | `./install.sh --headless --gpu cpu --install webui` | ❌ Aborted | Run halted after apt queued 500+ packages; manual interrupt to avoid long install. Output captured in `headless-webui-20251206T175634Z.log`. |

Interactive menu runs were not attempted because the container lacks a GUI/YAD display service.

## Reproduction steps
1. Ensure `install.sh` is executable: `chmod +x install.sh`.
2. Run the headless installer for a target, e.g. `./install.sh --headless --gpu cpu --install webui`.
3. Inspect logs under `qa_logs/` (timestamped per run).

## Issues observed
1. **Config service CLI ordering**
   - **Symptom:** Installer failed immediately with `config_service.py: error: unrecognized arguments: --config ...`.
   - **Root cause hypothesis:** `config_helpers.sh` passed the global `--config` argument after the subcommand, so argparse treated it as unknown.
   - **Mitigation:** Adjusted helper calls to place `--config` before the subcommand.
2. **Headless JSON config parser syntax**
   - **Symptom:** `install.sh` hit a syntax error in `parse_json_config` due to misordered heredoc redirection.
   - **Root cause hypothesis:** Command substitution constructed as `python3 - <<'PY' "$file"`, leaving the here-doc unterminated.
   - **Mitigation:** Reordered the heredoc so the file argument is passed before the delimiter.
3. **WebUI headless run aborted**
   - **Symptom:** Apt attempted to install ~547 packages (~409 MB). Run was interrupted (exit code 130) to keep the environment responsive.
   - **Root cause hypothesis:** Minimal container image lacked GUI/node/aria2 dependencies; bootstrap auto-installed them in headless mode, triggering a large download. Completing the run would still need WebUI repository/model downloads.
   - **Next steps:** Re-run on a provisioned runner with sufficient bandwidth/storage, or preseed dependencies to avoid long bootstrap time. Keep the log from `qa_logs/headless-webui-20251206T175634Z.log` attached to any follow-up issue.

## Follow-up tickets to file
- Document or implement a lighter-weight smoke mode to avoid full package/model downloads when only validating control flow.
- Re-run the full target matrix (webui, kobold, sillytavern, loras, models) on a GUI-capable host and capture pass/fail logs once dependencies are preinstalled.
