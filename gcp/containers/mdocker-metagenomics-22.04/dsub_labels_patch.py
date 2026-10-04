#!/usr/bin/env python3
"""Patch dsub's google-batch provider to label the VMs it creates.

dsub sets its labels (job-name, job-id, user-id, task-id and every --label)
only on the Batch Job. Batch documents Job.labels as applying to the job and
its Cloud Logging entries, not to the Compute Engine resources it creates;
those only receive AllocationPolicy.labels. Billing reports group by the
labels on the billed VMs and disks, so under google-batch the dsub labels are
invisible there (under google-cls-v2 they reached the VMs).

This patch copies the same label dict onto the allocation policy.

Fails loudly if the upstream source no longer matches, so a dsub bump forces a
re-review rather than silently shipping an unpatched image.

Usage:
  dsub_labels_patch.py            patch the installed dsub (build-time use)
  dsub_labels_patch.py FILE       patch a standalone copy (for testing)
"""

import importlib.util
import pathlib
import re
import sys

EXPECTED_DSUB_VER = "0.5.4"

ALLOC_RE = re.compile(
    r"^( *)allocation_policy = google_batch_operations\.build_allocation_policy\(\n"
    r"(?:\1 .*\n)*?"
    r"\1\)\n",
    re.MULTILINE,
)
PATCHED_LINE = "allocation_policy.labels = labels"


def fail(msg):
    print(f"dsub labels patch: FAILED: {msg}", file=sys.stderr)
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
            "label handling in build_allocation_policy before bumping EXPECTED_DSUB_VER"
        )
    return pathlib.Path(spec.origin), ver


def patch_text(text):
    matches = ALLOC_RE.findall(text)
    if len(matches) != 1:
        fail(f"expected 1 build_allocation_policy(...) call, found {len(matches)}")
    # labels must already be built by the time the allocation policy is
    if not re.search(r"^ *labels = \{", text[: ALLOC_RE.search(text).start()], re.MULTILINE):
        fail("labels dict is not defined before build_allocation_policy(...)")

    text = ALLOC_RE.sub(lambda m: m.group(0) + f"{m.group(1)}{PATCHED_LINE}\n", text)

    if text.count(PATCHED_LINE) != 1:
        fail("expected exactly 1 allocation_policy.labels assignment after substitution")
    return text


if len(sys.argv) > 1:
    path, ver = pathlib.Path(sys.argv[1]), "test-copy"
else:
    path, ver = installed_dsub_path()

text = path.read_text()
if text.count(PATCHED_LINE) == 1:
    print(f"dsub labels patch: already applied to {path}")
    sys.exit(0)

text = patch_text(text)

# reject a patch that would leave the provider unimportable
compile(text, str(path), "exec")
path.write_text(text)

print(f"dsub labels patch: applied to {path} (dsub {ver})")
for line in text.splitlines():
    if PATCHED_LINE in line:
        print(f"  {line.strip()}")
