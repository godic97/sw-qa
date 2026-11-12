#!/usr/bin/env bash
# Restores the fixture repository (with its full history) from repo.bundle into
# the empty eval workspace. answer-key.json next to this file lists the planted
# defects; it is never copied into the workspace.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git clone -q "$here/repo.bundle" .
git remote remove origin
