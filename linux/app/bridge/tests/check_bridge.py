#!/usr/bin/env python3
"""Exercise the real Swift core boundary without writing the human review record."""

import json
import os
from pathlib import Path
import sqlite3
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


def completed_at(directory, rule_id):
    connection = sqlite3.connect(Path(directory) / "chotki.sqlite")
    row = connection.execute(
        "select completed_at from occurrence where rule_id = ? and status = 'completed'",
        (rule_id,),
    ).fetchone()
    connection.close()
    return None if row is None else row[0]


def main():
    helper = sys.argv[1]
    human_review = Path.home() / ".cache" / "chotki-linux-review" / "chotki.sqlite"
    human_before = human_review.stat().st_mtime_ns if human_review.exists() else None

    with tempfile.TemporaryDirectory(prefix="chotki-review-check-") as review_dir:
        environment = os.environ.copy()
        environment["CHOTKI_LINUX_REVIEW_DIR"] = review_dir
        review, ask = conversation(helper, "--review", environment)
        assert ask("hello")["mode"] == "review"
        first = ask("snapshot")
        assert first["ok"] and first["psalmOneVerses"] == 6
        assert first["entries"] and len(first["week"]) == 7
        entry = next(item for item in first["entries"] if not item["dispensed"])
        changed = ask("toggleKept", ruleID=entry["id"])
        changed_entry = next(item for item in changed["entries"] if item["id"] == entry["id"])
        assert changed_entry["kept"] != entry["kept"]
        if changed_entry["kept"]:
            assert completed_at(review_dir, entry["id"])
        restored = ask("toggleKept", ruleID=entry["id"])
        restored_entry = next(item for item in restored["entries"] if item["id"] == entry["id"])
        assert restored_entry["kept"] == entry["kept"]
        if restored_entry["kept"]:
            assert completed_at(review_dir, entry["id"])
        calendar_day = ask("selectDate", date="2026-10-06")
        assert calendar_day["dayTitle"] and calendar_day["observedDate"]
        assert all("fast" in day and "feast" in day and "settled" in day
                   for day in calendar_day["week"])
        bright_week = ask("selectDate", date="2027-05-05")
        fast = next(item for item in bright_week["entries"]
                    if item["title"] == "The Wednesday and Friday fast")
        assert fast["dispensed"]
        refused = ask("toggleKept", ruleID=fast["id"])
        assert not refused["ok"]
        assert "asked" in refused["error"]
        missing = ask("toggleKept", ruleID="00000000-0000-0000-0000-000000000000")
        assert not missing["ok"]
        assert "not on the selected day" in missing["error"]
        shifted = ask("shiftWeek", direction=1)
        assert shifted["selectedDate"] == bright_week["selectedDate"]
        assert shifted["week"][0]["date"] != bright_week["week"][0]["date"]
        assert not ask("selectDate", date="not-a-date")["ok"]
        close(review)
        assert (Path(review_dir) / "chotki.sqlite").is_file()

    human_after = human_review.stat().st_mtime_ns if human_review.exists() else None
    assert human_before == human_after

    relative = os.environ.copy()
    relative["CHOTKI_LINUX_REVIEW_DIR"] = "not-absolute"
    rejected = subprocess.run(
        [helper, "--review"], input='{"v":1,"id":1,"op":"hello"}\n',
        text=True, capture_output=True, env=relative, timeout=5,
    )
    assert rejected.returncode != 0
    assert "absolute path" in rejected.stdout

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
