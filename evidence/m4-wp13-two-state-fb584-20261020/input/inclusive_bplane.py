#!/usr/bin/env python3
"""Inclusive sample accounting for the saved job-3383 perf.data files."""
import gzip
import json
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

HEADER = re.compile(r'^\S+\s+\d+\s+[0-9.]+:\s+(\d+)\s+task-clock:')
FRAME = re.compile(r'^\s+[0-9a-fA-F]+\s+(.+)$')

# perf script shortens inline C++ names. Keep a deliberately broad list of
# plane-specific helpers and every visible vvp_vector4_t API frame; it errs
# toward a higher (optimistic) ceiling when an inline name is ambiguous.
PLANE_NAMES = {
    'copy_from_big_', 'copy_inverted_from_', 'allocate_words_',
    'vvp_vector4_t', '~vvp_vector4_t', 'vvp_vector4array_t',
    'vvp_vector4array_sa', 'vvp_vector4array_aa',
    'get_word_', 'get_word', 'set_word_', 'set_word',
    'resize', 'set_bit', 'setarray',
    'set_vec', 'subarray', 'mul', 'add', 'sub', 'eeq', 'eq_xz', 'has_xz',
    'operator=', 'operator&=', 'operator|=', 'operator^=',
    'vec4_value', 'vec4_part_value', 'vec4_preponed_value',
    'filtered_value_', 'filter_vec4', 'force_fil_vec4', 'release_pv',
    'is_forced', 'copy_from_', 'fill_bits',
    'send_vec4', 'send_vec4_pv', 'vvp_send_vec4', 'vvp_send_vec4_pv',
    'recv_vec4', 'recv_vec4_pv', 'recv_vec4_', 'recv_vec4_pv_',
    'recv_vec4_base_', 'recv_vec4_from_inputs', 'check_word_change',
    'compare_gtge', 'do_CMPE', 'vector4_to_value',
    'vpip_vec4_to_int64_saturated',
    'calculate', 'calculate_result', 'receive',
}
PLANE_EXACT_NAMES = {
    'vvp_fun_and::calculate', 'vvp_fun_or::calculate',
    'vvp_fun_boolean_::receive', 'vvp_reduce_and::calculate_result',
    'vvp_vector2_t::copy_from_that_',
}
OPCODE_NAMES = {
    'of_LOAD_VEC4', 'of_LOAD_VEC4_PARTI', 'of_LOAD_VEC4_PART_base_',
    'of_LOAD_VEC4_PART_S', 'of_LOAD_VEC4_PART_U', 'of_LOAD_VEC4A',
    'of_STORE_VEC4', 'of_STORE_VEC4A',
}


def canonical(frame):
    value = re.sub(r'\s+\(inlined\)$', '', frame.strip())
    value = re.sub(r'\s+\([^)]*/[^)]*\)$', '', value)
    value = re.sub(r'\+0x[0-9a-fA-F]+$', '', value)
    return value.split('(', 1)[0].rstrip()


def short_name(name):
    return name.rsplit('::', 1)[-1]


def parse_lines(lines):
    inclusive = defaultdict(int)
    total = plane_union = opcode_union = vec4_value_union = 0
    weight = 0
    frames = []

    def finish():
        nonlocal total, plane_union, opcode_union, vec4_value_union, weight, frames
        if weight:
            names = {canonical(frame) for frame in frames}
            selected = {
                name for name in names
                if (
                    (('<' not in name) and short_name(name) in PLANE_NAMES)
                    or name in PLANE_EXACT_NAMES
                    or 'vector4_to_value<' in name
                    or 'vvp_vector4_t' in name
                )
            }
            opcodes = {
                name for name in names
                if '<' not in name and short_name(name) in OPCODE_NAMES
            }
            total += weight
            if selected:
                plane_union += weight
            if opcodes:
                opcode_union += weight
            if any(short_name(name) == 'vec4_value' for name in names):
                vec4_value_union += weight
            for name in selected:
                inclusive[name] += weight
        weight, frames = 0, []

    for line in lines:
        header = HEADER.match(line)
        if header:
            finish()
            weight = int(header.group(1))
            continue
        frame = FRAME.match(line)
        if frame:
            frames.append(frame.group(1))
        elif not line.strip():
            finish()
    finish()
    assert total > 0, 'no task-clock samples parsed'
    assert plane_union <= total and opcode_union <= total
    assert vec4_value_union <= plane_union
    return total, plane_union, opcode_union, vec4_value_union, inclusive


def main(path):
    with tempfile.NamedTemporaryFile(prefix='wp13-perf-', suffix='.data') as raw:
        with gzip.open(path, 'rb') as src:
            raw.write(src.read())
        raw.flush()
        proc = subprocess.Popen(
            ['perf', 'script', '--inline', '-i', raw.name, '--max-stack', '256'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        total, plane, opcodes, read, symbols = parse_lines(proc.stdout)
        error = proc.stderr.read()
        status = proc.wait()
        if status:
            raise RuntimeError(error)
    pct = lambda n: 100.0 * n / total
    print(json.dumps({
        'profile': str(path),
        'sample_weight': total,
        'plane_union_pct': pct(plane),
        'plane_union_ceiling': 1.0 / (1.0 - plane / total),
        'opcode_union_pct_not_credited': pct(opcodes),
        'unqualified_vec4_value_union_pct_upper_bound': pct(read),
        'unqualified_vec4_value_ceiling_upper_bound': 1.0 / (1.0 - read / total),
        'inclusive_symbol_pct': {
            name: pct(weight) for name, weight in sorted(symbols.items(), key=lambda item: (-item[1], item[0]))
        },
    }, indent=2))


if __name__ == '__main__':
    # Repeated frames count once per sample; nested symbols are inclusive and
    # overlap, while the union never double-counts a sample.
    sample = [
        'vvp 1 1.0: 10 task-clock:',
        '  1234 vvp_vector4_t::copy_from_big_+0x1 (/tmp/vvp)',
        '  5678 vec4_value+0x1 (inlined)',
        '',
        'vvp 1 2.0: 20 task-clock:',
        '  1234 copy_from_big_+0x1 (inlined)',
        '',
    ]
    total, union, opcodes, reads, symbols = parse_lines(sample)
    assert (total, union, opcodes, reads) == (30, 30, 0, 10)
    assert symbols['vvp_vector4_t::copy_from_big_'] == 10
    assert symbols['copy_from_big_'] == 20
    main(Path(sys.argv[1]))
