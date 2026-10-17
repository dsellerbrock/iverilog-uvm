#!/usr/bin/env bash
set -euo pipefail

retry_exit=
if [[ ${1:-} == --retry-exit ]]; then
  if (($# < 2)) || [[ ! $2 =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 [--retry-exit STATUS] -- COMMAND [ARG ...]" >&2
    exit 2
  fi
  retry_exit=$2
  shift 2
fi

if [[ ${1:-} != -- ]]; then
  echo "Usage: $0 [--retry-exit STATUS] -- COMMAND [ARG ...]" >&2
  exit 2
fi
shift
if (($# == 0)); then
  echo "No command provided." >&2
  exit 2
fi

command=("$@")
delays=(30 60 120 240)
for attempt in 1 2 3 4 5; do
  echo "MSYS2 command attempt $attempt/5: ${command[*]}"
  if "${command[@]}"; then
    echo "MSYS2 command succeeded on attempt $attempt/5."
    exit 0
  else
    status=$?
  fi

  if [[ -n $retry_exit && $status -ne $retry_exit ]]; then
    echo "::error::MSYS2 command failed with non-retryable exit $status."
    exit "$status"
  fi
  if ((attempt == 5)); then
    echo "::error::MSYS2 command failed after 5 attempts (exit $status)."
    exit "$status"
  fi

  delay=${delays[$((attempt - 1))]}
  echo "MSYS2 command failed with exit $status; refreshing package database before retry in ${delay}s."
  if pacman -Syy --noconfirm; then
    :
  else
    refresh_status=$?
    echo "::warning::pacman -Syy failed with exit $refresh_status; continuing with retry."
  fi
  sleep "$delay"
done
