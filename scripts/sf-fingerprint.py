#!/usr/bin/env python3
"""Print a content fingerprint of the Salesforce package directories (from sfdx-project.json).

Used to tie an org-test run to the exact source it tested: change a file and the fingerprint
changes, so an old "tests passed" record can no longer vouch for new code.
"""
import hashlib
import json
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.getcwd()

info = json.loads(subprocess.check_output([sys.executable, os.path.join(here, "detect-stacks.py")], cwd=root))
dirs = (info.get("salesforce") or {}).get("packageDirs", [])

h = hashlib.sha1()
for d in sorted(dirs):
    for dirpath, dirnames, filenames in os.walk(os.path.join(root, d)):
        dirnames.sort()
        for name in sorted(filenames):
            path = os.path.join(dirpath, name)
            h.update(os.path.relpath(path, root).encode())
            h.update(b"\0")
            with open(path, "rb") as f:
                h.update(hashlib.sha1(f.read()).digest())
print(h.hexdigest())
