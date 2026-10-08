#!/usr/bin/env python3
"""Exercise the real Swift core boundary with an isolated review record."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def conversation(helper: str, mode: str, environment=None):
    process = subprocess.Popen(
        [helper, mode], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, env=environment,
    )
    next_id = 0

    def ask(operation, **fields):
        nonlocal next_id
        next_id += 1
        request = {"v": 1, "id": next_id, "op": operation, **fields}
        process.stdin.write(json.dumps(request) + "\n")
        process.stdin.flush()
        line = process.stdout.readline()
        assert line, f"helper ended during {operation}: {process.stderr.read()}"
        response = json.loads(line)
        assert response["v"] == 1 and response["id"] == next_id, response
        return response

    return process, ask


def close(process):
    process.stdin.close()
    assert process.wait(timeout=5) == 0, process.stderr.read()


def main():
    helper = sys.argv[1]
    review, ask = conversation(helper, "--review")
    assert ask("hello")["mode"] == "review"
    first = ask("snapshot")
    assert first["ok"] and first["psalmOneVerses"] == 6
    assert first["entries"] and len(first["week"]) == 7
    entry = next(item for item in first["entries"] if not item["dispensed"])
    changed = ask("toggleKept", ruleID=entry["id"])
    changed_entry = next(item for item in changed["entries"] if item["id"] == entry["id"])
    assert changed_entry["kept"] != entry["kept"]
    restored = ask("toggleKept", ruleID=entry["id"])
    restored_entry = next(item for item in restored["entries"] if item["id"] == entry["id"])
    assert restored_entry["kept"] == entry["kept"]
    calendar_day = ask("selectDate", date="2026-10-06")
    assert calendar_day["dayTitle"] and calendar_day["observedDate"]
    assert all("fast" in day and "feast" in day and "settled" in day
               for day in calendar_day["week"])
    shifted = ask("shiftWeek", direction=1)
    assert shifted["selectedDate"] == calendar_day["selectedDate"]
    assert shifted["week"][0]["date"] != calendar_day["week"][0]["date"]
    assert not ask("selectDate", date="not-a-date")["ok"]
    close(review)

    with tempfile.TemporaryDirectory(prefix="chotki-normal-check-") as directory:
        environment = os.environ.copy()
        environment["XDG_DATA_HOME"] = directory
        normal, ask = conversation(helper, "--normal", environment)
        assert ask("hello")["mode"] == "normal"
        snapshot = ask("snapshot")
        assert snapshot["entries"] == []
        assert not ask("setReviewName", name="Must fail")["ok"]
        close(normal)
        assert (Path(directory) / "Chotki" / "chotki.sqlite").is_file()

    print("Swift bridge review actions and normal-data isolation passed")


if __name__ == "__main__":
    main()
