#!/usr/bin/env python3
"""Patch dsub's google-batch ListJobs so a status-read error does not kill --wait.

lookup_job_tasks pages ListJobs. A 502/503/504 there aborts dsub --wait, and
that process is also the spot/on-demand retry loop: a task that fails later
is resubmitted only while --wait is still running. The Batch jobs themselves
keep running. Sleep and list the same jobs again.

Fails loudly if the upstream source no longer matches, so a dsub bump forces a
re-review rather than silently shipping an unpatched image.

Usage:
  dsub_list_retry_patch.py            patch the installed dsub (build-time use)
  dsub_list_retry_patch.py FILE       patch a standalone copy (for testing)
"""

import importlib.util
import pathlib
import re
import sys

EXPECTED_DSUB_VER = "0.5.4"

OLD = """\
    # Make the request
    response = client.list_jobs(request=request)
    # Sort the operations by create-time to match sort of other providers
    operations = [GoogleBatchOperation(page) for page in response]
"""

NEW = """\
    # a 502/503/504 here is a failed status read; the jobs keep running
    import time
    from google.api_core import exceptions
    delay = 15
    while True:
      try:
        response = client.list_jobs(request=request)
        operations = [GoogleBatchOperation(page) for page in response]
        break
      except (
          exceptions.DeadlineExceeded,
          exceptions.ServiceUnavailable,
          exceptions.InternalServerError,
          exceptions.TooManyRequests,
          exceptions.Aborted,
          exceptions.BadGateway,
          exceptions.GatewayTimeout,
      ) as exc:
        print(
            'list_jobs %s: %s; retrying in %ds' % (type(exc).__name__, exc, delay),
            flush=True,
        )
        time.sleep(delay)
        delay = min(delay * 2, 60)
    # Sort the operations by create-time to match sort of other providers
"""

MARKER = "list_jobs %s: %s; retrying in %ds"


def fail(msg):
    print(f"dsub list retry patch: FAILED: {msg}", file=sys.stderr)
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
            "lookup_job_tasks before bumping EXPECTED_DSUB_VER"
        )
    return pathlib.Path(spec.origin), ver


def patch_text(text):
    count = text.count(OLD)
    if count != 1:
        fail(f"expected 1 ListJobs call in lookup_job_tasks, found {count}")
    text = text.replace(OLD, NEW, 1)
    if text.count(MARKER) != 1:
        fail("retry loop missing after substitution")
    if text.count(OLD) != 0:
        fail("original ListJobs call still present after substitution")
    return text


if len(sys.argv) > 1:
    path, ver = pathlib.Path(sys.argv[1]), "test-copy"
else:
    path, ver = installed_dsub_path()

text = path.read_text()
if text.count(MARKER) == 1:
    print(f"dsub list retry patch: already applied to {path}")
    sys.exit(0)

text = patch_text(text)

# reject a patch that would leave the provider unimportable
compile(text, str(path), "exec")
path.write_text(text)

print(f"dsub list retry patch: applied to {path} (dsub {ver})")
for line in text.splitlines():
    if MARKER in line:
        print(f"  {line.strip()}")
