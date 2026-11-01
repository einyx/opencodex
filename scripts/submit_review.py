#!/usr/bin/env python3
"""Submit the App Store version for review.

    python3 scripts/submit_review.py            # report the state
    python3 scripts/submit_review.py --submit   # submit it for review
    python3 scripts/submit_review.py --shots    # also upload the review screenshots

The App Store Connect submission is a three-step workflow, and the order
matters — see `docs/lessons.md` §23 for why the obvious routes fail:

1. `POST /v1/reviewSubmissions` with the platform attribute *and* the app
   relationship. A submission created without the platform comes back with
   `platform: null`, and Apple then refuses every later step with "Resource
   is not in submittable state". Review submissions cannot be deleted, so
   such a shell is an orphan for good.
2. `POST /v1/reviewSubmissionItems` with the submission and the version.
   This is what moves the version from `PREPARE_FOR_SUBMISSION` to
   `READY_FOR_REVIEW`.
3. `PATCH /v1/reviewSubmissions/{id}` with `submitted: true`. Only this
   sends the version to App Review: the submission gets a `submittedDate`
   and moves to `WAITING_FOR_REVIEW`.

The script is idempotent: a draft submission that already carries the
version is reused, and only the last step is repeated.

Swapping the build of a version that is already in review is a separate
route — `scripts/asc_attach_build.py <build> --withdraw` cancels the
submission first, because Apple locks the build of a version in review.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import time

APP_ID = "6826903678"
VERSION_ID = "8fbf4b93-cc24-43d7-8087-83517987cb41"
SET_ID = "e0a557ea-aa70-414a-a91d-b6528b7e6b93"  # APP_IPHONE_61
SHOTS = sorted((pathlib.Path(__file__).resolve().parent.parent / ".occlient" / "review-shots").glob("shot*.png"))
API = pathlib.Path(__file__).with_name("asc_api.py")


def call(method: str, path: str, payload: dict | None = None) -> dict:
    """Calls the App Store Connect API through `scripts/asc_api.py`."""
    args = [sys.executable, str(API), method, path]
    if payload is not None:
        args.append(json.dumps(payload))
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"the API call failed: {result.stderr.strip()}")
    if not result.stdout.strip():
        return {}  # a 204 No Content — the relationship was set
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        raise SystemExit(f"unexpected API response: {result.stdout[:400]}")
    # `asc_api.py` prints the body whatever the status was, so an error is
    # a body with an "errors" array, not a non-zero exit code.
    if isinstance(data, dict) and "errors" in data:
        raise SystemExit(f"{method} {path} failed: {json.dumps(data['errors'])[:400]}")
    return data


def upload_screenshot(png: pathlib.Path, order: int) -> None:
    """Uploads one screenshot to the app's iPhone 6.1 screenshot set."""
    import urllib.request

    data = png.read_bytes()
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": png.name, "fileSize": len(data)},
            "relationships": {
                "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": SET_ID}}
            },
        }
    }
    created = call("POST", "/v1/appScreenshots", body)
    shot_id = created["data"]["id"]
    for op in created["data"].get("attributes", {}).get("uploadOperations", []):
        offset = op.get("offset", 0)
        length = op.get("length", len(data))
        request = urllib.request.Request(op["url"], data=data[offset:offset + length], method=op["method"])
        with urllib.request.urlopen(request, timeout=300) as response:
            response.read()
    call("PATCH", f"/v1/appScreenshots/{shot_id}", {
        "data": {"type": "appScreenshots", "id": shot_id, "attributes": {"uploaded": True}}
    })
    print(f"  uploaded {png.name} -> {shot_id} ({order + 1})")


def find_draft_submission() -> str | None:
    """The submission that already carries the version, if there is one."""
    submissions = call("GET", f"/v1/reviewSubmissions?filter[app]={APP_ID}").get("data", [])
    for submission in submissions:
        if submission["attributes"].get("state") != "READY_FOR_REVIEW":
            continue
        items = call("GET", f"/v1/reviewSubmissions/{submission['id']}/items").get("data", [])
        if any(item["attributes"].get("state") != "REMOVED" for item in items):
            return submission["id"]
    return None


def create_submission() -> str:
    """Creates the submission shell, with the platform the reviewer needs."""
    created = call("POST", "/v1/reviewSubmissions", {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    submission_id = created["data"]["id"]
    print(f"created submission {submission_id}")
    return submission_id


def add_version(submission_id: str) -> None:
    """Puts the version into the submission."""
    call("POST", "/v1/reviewSubmissionItems", {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}},
            },
        }
    })
    print("added the version to the submission")


def commit(submission_id: str) -> None:
    """Sends the submission to App Review."""
    call("PATCH", f"/v1/reviewSubmissions/{submission_id}", {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"submitted": True},
        }
    })
    print("submitted for review")


def main() -> int:
    shots = "--shots" in sys.argv
    submit = "--submit" in sys.argv

    version = call("GET", f"/v1/appStoreVersions/{VERSION_ID}")["data"]
    attributes = version["attributes"]
    state = attributes["appStoreState"]
    print(f"version {attributes['versionString']} is {state}")
    build = call("GET", f"/v1/appStoreVersions/{VERSION_ID}/build").get("data", {})
    if build:
        print(f"  build {build['attributes']['version']}")

    if shots:
        for index, shot in enumerate(SHOTS):
            print(f"screenshot {index + 1}/{len(SHOTS)}")
            upload_screenshot(shot, index)

    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
        print("already in the review queue — nothing to do")
        return 0

    if not submit:
        print("NOT submitting (pass --submit when the metadata is final)")
        return 0

    submission_id = find_draft_submission()
    if submission_id:
        print(f"reusing submission {submission_id}")
    else:
        submission_id = create_submission()
        add_version(submission_id)

    commit(submission_id)
    time.sleep(3)
    final = call("GET", f"/v1/appStoreVersions/{VERSION_ID}")["data"]["attributes"]
    print(f"version is now {final['appStoreState']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
