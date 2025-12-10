from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.runtime.web_launcher import server  # noqa: E402


def test_gpu_endpoint_delegates_to_helper(monkeypatch):
    called = {"count": 0}

    def fake_collect():
        called["count"] += 1
        return {"summary": {"platform": "TestOS", "backends": {}}, "gpus": [{"vendor": "NVIDIA", "name": "Test"}]}

    monkeypatch.setattr(server, "collect_gpu_diagnostics", fake_collect)

    project_root = Path(__file__).resolve().parents[2]
    api = server.WebLauncherAPI(project_root=project_root)
    diagnostics = api.gpu_diagnostics()

    assert called["count"] == 1
    assert diagnostics["gpus"][0]["name"] == "Test"
