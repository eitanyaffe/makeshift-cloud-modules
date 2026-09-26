#!/usr/bin/env python3
"""Patch dsub's continuous log-uploader so it cannot kill a healthy task.

dsub's `_LOG_CP` bash launches three `gcloud storage cp` calls in parallel and
waits on each. Two problems:

1. Google documents that parallel gcloud invocation is unsupported
   (https://cloud.google.com/sdk/docs/scripting-gcloud) - the three processes
   share ~/.config/gcloud/access_tokens.db and race on its sqlite lock,
   producing "database is locked" / "gcloud crashed (OperationalError)".
   dsub's own 4-attempt retry can exhaust itself on a hot lock.
2. The uploader is a background runnable but is not marked
   ignore_exit_status, so its exit 1 marks the whole Batch task FAILED long
   after the user command has already succeeded.

This patch serializes the three copies and makes each one non-fatal. The
subshell matters: dsub's gcloud_cp ends in `exit 1`, which without `&` to
contain it would terminate the logging loop outright, and `|| true` does not
stop `exit`.

Fails loudly if the upstream source no longer matches, so a dsub bump forces a
re-review rather than silently shipping an unpatched image.

Usage:
  dsub_logging_patch.py            patch the installed dsub (build-time use)
  dsub_logging_patch.py FILE       patch a standalone copy (for testing)
"""

import importlib.util
import pathlib
import re
import sys

EXPECTED_DSUB_VER = "0.5.4"

LAUNCH_RE = re.compile(r"^( *)(gcloud_cp .*?) *&$", re.MULTILINE)
PID_RE = re.compile(r"^ *(?:STDOUT|STDERR|LOG)_PID=\$!\n", re.MULTILINE)
WAIT_RE = re.compile(r"^ *wait \"\$\{\{(?:STDOUT|STDERR|LOG)_PID\}\}\"\n", re.MULTILINE)
PATCHED_RE = re.compile(r"^ *\( gcloud_cp .*? \) \|\| true$", re.MULTILINE)


def fail(msg):
    print(f"dsub logging patch: FAILED: {msg}", file=sys.stderr)
    sys.exit(1)


def installed_dsub_path():
    spec = importlib.util.find_spec("dsub.providers.google_batch")
    if spec is None or not spec.origin:
        fail("cannot locate dsub.providers.google_batch")
    ver_spec = importlib.util.find_spec("dsub._dsub_version")
    match = re.search(
        r"DSUB_VERSION\s*=\s*'([^']+)'", pathlib.Path(ver_spec.origin).read_text()
    )
    ver = match.group(1).lstrip("v")
    if ver != EXPECTED_DSUB_VER:
        fail(
            f"dsub is {ver}, patch written against {EXPECTED_DSUB_VER}; re-verify "
            "_LOG_CP upstream before bumping EXPECTED_DSUB_VER"
        )
    return pathlib.Path(spec.origin), ver


def patch_text(text):
    counts = (
        len(LAUNCH_RE.findall(text)),
        len(PID_RE.findall(text)),
        len(WAIT_RE.findall(text)),
    )
    if counts != (3, 3, 3):
        fail(f"expected 3 launches / 3 pid vars / 3 waits, found {counts}")

    text = LAUNCH_RE.sub(r"\1( \2 ) || true", text)
    text = PID_RE.sub("", text)
    text = WAIT_RE.sub("", text)

    if LAUNCH_RE.search(text) or PID_RE.search(text) or WAIT_RE.search(text):
        fail("residual parallel-launch constructs after substitution")
    if len(PATCHED_RE.findall(text)) != 3:
        fail("expected 3 serialized copies after substitution")
    return text


if len(sys.argv) > 1:
    path, ver = pathlib.Path(sys.argv[1]), "test-copy"
else:
    path, ver = installed_dsub_path()

text = path.read_text()
if not LAUNCH_RE.search(text) and len(PATCHED_RE.findall(text)) == 3:
    print(f"dsub logging patch: already applied to {path}")
    sys.exit(0)

text = patch_text(text)

# reject a patch that would leave the provider unimportable
compile(text, str(path), "exec")
path.write_text(text)

print(f"dsub logging patch: applied to {path} (dsub {ver})")
for line in text.splitlines():
    if "gcloud_cp" in line and "|| true" in line:
        print(f"  {line.strip()}")
