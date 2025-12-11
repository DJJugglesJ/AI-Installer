from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.runtime.web_launcher import server  # noqa: E402
from modules.runtime.models import tasks  # noqa: E402


def test_voice_profiles_tool_wired(monkeypatch, tmp_path):
    project_root = Path(__file__).resolve().parents[2]
    api = server.WebLauncherAPI(project_root=project_root, config_path=tmp_path / "config.yaml")

    calls = {"count": 0}

    def fake_list_voice_profiles():
        calls["count"] += 1
        task = tasks.new_task("voice_profiles", payload={"source": "test"})
        tasks.mark_running(task)
        return tasks.mark_succeeded(task, result={"profiles": [{"id": "demo"}]})

    monkeypatch.setattr(server.voice_profiles_services, "list_voice_profiles", fake_list_voice_profiles)

    result = api.create_task("voice_profiles", {})

    assert calls["count"] == 1
    assert result["kind"] == "voice_profiles"
    assert result["result"]["profiles"][0]["id"] == "demo"
    assert result["id"] in api._tasks
    assert api._tasks[result["id"]].result["profiles"][0]["id"] == "demo"
