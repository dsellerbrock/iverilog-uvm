#!/usr/bin/env python3
"""Resolve a FuseSoC core and its dependencies, dump the file list.

Usage:
  python3 scripts/fusesoc_resolve.py <core_name> [--top <top_level>]

Example:
  python3 scripts/fusesoc_resolve.py lowrisc:ip:otbn:0.1
"""

import os
import sys
import argparse

# Add the opentitan-upstream directory as a cores-root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OT_ROOT = os.path.join(os.path.dirname(REPO_ROOT), 'opentitan-upstream')

sys.path.insert(0, OT_ROOT)

from fusesoc.coremanager import CoreManager
from fusesoc.config import Config


def resolve_core(core_name, target='default'):
    """Resolve a FuseSoC core and return its dependency tree."""
    config = Config()
    config.build_root = os.path.join(REPO_ROOT, 'build')
    
    cm = CoreManager(config)
    
    # Add opentitan as cores root
    cm.add_library('opentitan', OT_ROOT)
    
    # Find the core
    core = cm._cores.get(core_name)
    if core is None:
        print(f"ERROR: Core '{core_name}' not found.", file=sys.stderr)
        # List available OT cores
        ot_cores = [k for k in cm._cores.keys() if 'otbn' in k.lower()]
        if ot_cores:
            print(f"OTBN-related cores found: {ot_cores}", file=sys.stderr)
        return None
    
    print(f"# Core: {core.name}")
    print(f"# Description: {core.description}")
    print(f"# Core root: {core.core_root}")
    
    # Resolve dependencies
    resolved = _resolve_deps(cm, core, target, set())
    
    return resolved


def _resolve_deps(cm, core, target, visited):
    """Recursively resolve dependencies for a core."""
    if core.name in visited:
        return {'includes': [], 'src_files': [], 'cores': []}
    
    visited.add(core.name)
    
    result = {
        'includes': [],
        'src_files': [],
        'cores': [core.name],
    }
    
    # Get target filesets
    target_info = core.get_target(target)
    if target_info is None:
        print(f"# WARNING: No target '{target}' for core '{core.name}', skipping", file=sys.stderr)
        return result
    
    filesets = target_info.get('filesets', [])
    
    for fs_name in filesets:
        if fs_name not in core.file_sets:
            continue
        
        fs = core.file_sets[fs_name]
        
        # Process dependencies first
        for dep_name in fs.get('depend', []):
            dep_core = cm._cores.get(dep_name)
            if dep_core is not None:
                dep_result = _resolve_deps(cm, dep_core, target, visited)
                result['includes'].extend(dep_result['includes'])
                result['src_files'].extend(dep_result['src_files'])
                result['cores'].extend(dep_result['cores'])
            else:
                print(f"# WARNING: Dependency '{dep_name}' not found for '{core.name}'", file=sys.stderr)
        
        # Process files
        core_dir = core.core_root
        for f in fs.get('files', []):
            full_path = os.path.join(core_dir, f)
            if os.path.exists(full_path):
                result['src_files'].append(os.path.abspath(full_path))
            elif os.path.exists(os.path.join(OT_ROOT, f)):
                result['src_files'].append(os.path.abspath(os.path.join(OT_ROOT, f)))
            else:
                print(f"# WARNING: File not found: {full_path}", file=sys.stderr)
        
        # Add core root as include path if there are files
        if fs.get('files'):
            abs_core_dir = os.path.abspath(core_dir)
            if abs_core_dir not in result['includes']:
                result['includes'].append(abs_core_dir)
    
    # Add dependencies' includes
    for dep_name in target_info.get('depend', []):
        dep_core = cm._cores.get(dep_name)
        if dep_core is not None and dep_core.core_root:
            abs_dep_dir = os.path.abspath(dep_core.core_root)
            if abs_dep_dir not in result['includes']:
                result['includes'].append(abs_dep_dir)
    
    return result


def find_all_cores():
    """List all cores matching OT-related patterns."""
    config = Config()
    cm = CoreManager(config)
    cm.add_library('opentitan', OT_ROOT)
    
    cores = sorted(cm._cores.keys())
    return cores


def main():
    parser = argparse.ArgumentParser(description='Resolve FuseSoC core dependencies')
    parser.add_argument('core', nargs='?', help='Core name (e.g. lowrisc:ip:otbn:0.1)')
    parser.add_argument('--target', default='default', help='Build target (default: default)')
    parser.add_argument('--list', action='store_true', help='List all available cores')
    parser.add_argument('--filter', help='Filter core list (case-insensitive substring match)')
    parser.add_argument('--iverilog-flags', default='-g2012', help='iverilog flags')
    
    args = parser.parse_args()
    
    if args.list or not args.core:
        cores = find_all_cores()
        if args.filter:
            cores = [c for c in cores if args.filter.lower() in c.lower()]
        for c in cores:
            print(c)
        return
    
    resolved = resolve_core(args.core, args.target)
    if resolved is None:
        sys.exit(1)
    
    # Print summary
    print(f"\n# Resolved {len(resolved['cores'])} cores")
    print(f"# Source files: {len(resolved['src_files'])}")
    print(f"# Include dirs: {len(resolved['includes'])}")
    
    # Build include flags
    include_flags = ' '.join(f'-I{d}' for d in resolved['includes'])
    
    # Print the iverilog compile command
    src_files = ' '.join(resolved['src_files'])
    print(f"\n# iverilog compile command:")
    print(f"iverilog {args.iverilog_flags} {include_flags} {src_files}")


if __name__ == '__main__':
    main()
