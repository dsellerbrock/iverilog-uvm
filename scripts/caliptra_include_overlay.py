#!/usr/bin/env python3
"""Resolve Caliptra RTL include directories with a small compatibility overlay."""

import argparse
import json
import os
from pathlib import Path
import re
import sys

import yaml


OVERLAY = {
    "abr_libs": ("abr_prim_pkg",),
    "abr_prim_generic": ("abr_prim_pkg",),
    "pcrvault": ("caliptra_prim_pkg",),
    "datavault": ("caliptra_prim_pkg",),
    "axi_sub": ("caliptra_prim_pkg",),
    "caliptra_prim_generic": ("caliptra_prim_pkg",),
    "aes": ("caliptra_top_reg_defines",),
}

_VARIABLE = re.compile(r"\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))")


class OverlayError(Exception):
    pass


def _expand(value, variables):
    def replace(match):
        name = match.group(1) or match.group(2)
        if name not in variables:
            raise OverlayError(f"unexpanded variable ${name} in {value}")
        return variables[name]

    expanded = _VARIABLE.sub(replace, value)
    if "$" in expanded:
        raise OverlayError(f"unexpanded variable in {value}")
    return expanded


def load_providers(corpus_root, variables=None):
    corpus_root = Path(corpus_root).resolve()
    supplied = dict(os.environ if variables is None else variables)
    providers = {}
    for metadata in sorted(corpus_root.glob("**/config/compile.yml")):
        compile_root = metadata.parent.parent.resolve()
        local_vars = dict(supplied)
        local_vars["COMPILE_ROOT"] = str(compile_root)
        try:
            documents = yaml.safe_load_all(metadata.read_text())
            for document_index, document in enumerate(documents, 1):
                if not document:
                    continue
                for name in document.get("provides", []) or []:
                    if name in providers:
                        previous = providers[name]
                        raise OverlayError(
                            f"duplicate provider {name}: {previous['metadata']} and {metadata}"
                        )
                    directories = []
                    target = (document.get("targets") or {}).get("rtl") or {}
                    for raw in target.get("directories", []) or []:
                        expanded = Path(_expand(str(raw), local_vars))
                        if not expanded.is_absolute():
                            raise OverlayError(
                                f"provider {name} has relative RTL directory {expanded}"
                            )
                        path = expanded.resolve()
                        if not path.is_dir():
                            raise OverlayError(
                                f"provider {name} has nonexistent RTL directory {path}"
                            )
                        directories.append(str(path))
                    providers[name] = {
                        "metadata": str(metadata),
                        "document": document_index,
                        "requires": list(document.get("requires", []) or []),
                        "rtl_directories": directories,
                    }
        except yaml.YAMLError as error:
            raise OverlayError(f"invalid YAML in {metadata}: {error}") from error
    return providers


def resolve(providers, roots, overlay=OVERLAY):
    ordered_providers = []
    state = {}

    def visit(name, chain):
        if name not in providers:
            raise OverlayError(f"missing provider {name} required by {' -> '.join(chain)}")
        if state.get(name) == "visiting":
            start = chain.index(name) if name in chain else 0
            raise OverlayError(f"provider cycle: {' -> '.join(chain[start:] + [name])}")
        if state.get(name) == "done":
            return
        state[name] = "visiting"
        requirements = list(providers[name]["requires"]) + list(overlay.get(name, ()))
        for dependency in requirements:
            visit(dependency, chain + [name])
        state[name] = "done"
        ordered_providers.append(name)

    for root in roots:
        visit(root, [])

    directories = []
    provenance = []
    seen_directories = set()
    for provider in ordered_providers:
        for directory in providers[provider]["rtl_directories"]:
            if directory in seen_directories:
                continue
            seen_directories.add(directory)
            directories.append(directory)
            provenance.append({"directory": directory, "provider": provider})
    return {
        "roots": list(roots),
        "providers": ordered_providers,
        "directories": directories,
        "provenance": provenance,
        "errors": [],
    }


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--corpus-root", required=True, type=Path)
    parser.add_argument("--job", action="append", required=True, dest="jobs")
    parser.add_argument("--env", action="append", default=[], metavar="NAME=VALUE")
    args = parser.parse_args(argv)
    variables = dict(os.environ)
    try:
        for assignment in args.env:
            name, separator, value = assignment.partition("=")
            if not separator or not name:
                raise OverlayError(f"invalid --env value {assignment!r}")
            variables[name] = value
        result = resolve(load_providers(args.corpus_root, variables), args.jobs)
    except OverlayError as error:
        json.dump({"roots": args.jobs, "directories": [], "provenance": [],
                   "errors": [str(error)]}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 2
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
