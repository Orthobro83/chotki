#!/usr/bin/env python3
"""Exercise the real Swift core boundary without writing the human review record."""

import json
import math
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


def occurrence_count(directory):
    connection = sqlite3.connect(Path(directory) / "chotki.sqlite")
    count = connection.execute("select count(*) from occurrence").fetchone()[0]
    connection.close()
    return count


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

        before_prayer = occurrence_count(review_dir)
        prayer = ask("prayer", diameter=240)["prayer"]
        assert prayer["selection"] == "jesus-prayer"
        assert prayer["ropeAlone"] is False
        assert prayer["count"] == 0 and prayer["target"] == 33
        assert prayer["showsRope"] is True and prayer["complete"] is False
        assert prayer["words"][0]["paragraphs"] == [
            "Lord Jesus Christ, Son of God, have mercy on me, a sinner."
        ]
        assert prayer["words"][0]["centred"] is True
        assert len(prayer["knots"]) == 33 and len(prayer["beads"]) == 4
        assert prayer["knots"][0]["mark"] == "next"
        assert prayer["beads"][0]["passed"] is True
        assert prayer["beads"][1]["passed"] is False
        assert 0 < prayer["dot"] <= 11
        assert abs(prayer["bead"] - prayer["dot"] * 1.4) < 1e-6
        assert all(0 <= knot["x"] <= 240 and 0 <= knot["y"] <= 240 for knot in prayer["knots"])
        smaller = ask("prayer", diameter=100)["prayer"]
        assert smaller["dot"] < prayer["dot"]

        base = 1_700_000_000
        sounds = []
        for step in range(33):
            counted = ask("advancePrayer", now=base + step)["prayer"]
            assert counted["count"] == step + 1
            assert counted["advanced"] is True
            sounds.append(counted["sound"])
        assert sounds[0] == "tick"
        assert sounds[9] == "tock" and sounds[19] == "tock" and sounds[29] == "tock"
        assert sounds[32] == "bell"
        assert counted["complete"] is True and counted["cue"] == "bell"
        assert counted["knots"][0]["mark"] == "counted"
        assert "next" not in {knot["mark"] for knot in counted["knots"]}
        held = ask("advancePrayer", now=base + 100)["prayer"]
        assert held["count"] == 33 and held["advanced"] is False and "sound" not in held
        returned = ask("prayer")["prayer"]
        assert returned["count"] == 33

        ask("startAgain")
        first = ask("advancePrayer", now=base)["prayer"]
        refused = ask("advancePrayer", now=base + 0.2)["prayer"]
        assert first["count"] == 1 and first["sound"] == "tick"
        assert refused["count"] == 1 and refused["advanced"] is False and "sound" not in refused
        assert ask("prayer")["prayer"]["count"] == 1

        alone = ask("choosePrayer", selection=None)["prayer"]
        assert alone["ropeAlone"] is True and alone["selection"] == ""
        assert alone["showsRope"] is True and alone["words"] == [] and alone["count"] == 1
        morning = ask("choosePrayer", selection="morning")["prayer"]
        assert morning["showsRope"] is False and morning["count"] == 1
        assert len(morning["words"]) == 11
        assert morning["words"][0]["title"] == "The Opening Prayer"
        assert morning["words"][0]["centred"] is False
        assert ask("showRope", shown=True)["prayer"]["showsRope"] is True
        jesus = ask("choosePrayer", selection="jesus-prayer")["prayer"]
        assert jesus["showsRope"] is True and jesus["selection"] == "jesus-prayer"
        aimed = ask("aimPrayer", target=100)["prayer"]
        assert aimed["target"] == 100 and aimed["count"] == 0 and len(aimed["beads"]) == 10
        assert not ask("aimPrayer", target=12)["ok"]
        unknown = ask("choosePrayer", selection="not-a-prayer")
        assert not unknown["ok"] and "not in the book" in unknown["error"]

        opening = ask("opening")["opening"]
        assert len(opening["knots"]) == 11 and opening["knotSlots"] == 12
        assert abs(opening["knotRadius"] - 0.042) < 1e-9
        assert abs(opening["build"] - 1.8) < 1e-9
        assert abs(opening["hold"] - 1.5) < 1e-9
        assert abs(opening["fade"] - 0.4) < 1e-9
        assert abs(opening["knotFade"] - 0.16) < 1e-9
        assert abs(opening["staggerLead"] - 0.2) < 1e-9
        angle = math.pi / 2 + (1 / 12) * 2 * math.pi
        assert abs(opening["knots"][0]["x"] - (0.5 + 0.30 * math.cos(angle))) < 1e-6
        assert abs(opening["knots"][0]["y"] - (0.36 + 0.30 * math.sin(angle))) < 1e-6
        assert len(opening["bars"]) == 3
        assert abs(opening["footrest"]["leadingX"] - 0.209) < 1e-9
        assert abs(opening["box"]["height"] - 0.34) < 1e-9
        tones = ask("tones")["tones"]
        for name in ("tick", "tock", "bell"):
            assert Path(tones[name]).read_bytes()[:4] == b"RIFF"
        assert ask("tones")["tones"] == tones
        assert occurrence_count(review_dir) == before_prayer
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
