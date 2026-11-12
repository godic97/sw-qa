#!/usr/bin/env bash
# Fixture: a tiny pricing module with a specification. Two requirements are
# violated (the discount boundary and the negative-amount check); the existing
# tests pass.
set -euo pipefail
export GIT_AUTHOR_NAME="Dana Park" GIT_AUTHOR_EMAIL="dana@example.com"
export GIT_COMMITTER_NAME="Dana Park" GIT_COMMITTER_EMAIL="dana@example.com"
export GIT_AUTHOR_DATE="2026-10-05T09:00:00+09:00" GIT_COMMITTER_DATE="2026-10-05T09:00:00+09:00"

git init -q -b main .

cat > SPEC.md <<'SPEC'
# 할인 규칙

- `discount(total)`: 주문 금액(원, 정수)을 받아 결제 금액을 반환한다.
- 주문 금액이 100,000원 이상이면 10% 할인한다.
- 100,000원 미만이면 할인하지 않는다.
- 음수 금액은 `ValueError`를 낸다.
SPEC

cat > shop.py <<'PY'
def discount(total):
    """Return the amount to pay for an order of `total` won."""
    if total > 100000:
        return int(total * 0.9)
    return total
PY

cat > test_shop.py <<'PY'
from shop import discount


def test_discount_applied():
    assert discount(200000) == 180000


def test_no_discount():
    assert discount(50000) == 50000
PY

git add -A
git -c commit.gpgsign=false commit -q -m "feat: order discount"
