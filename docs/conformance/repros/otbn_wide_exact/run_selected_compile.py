import hashlib
import json
import shlex
import subprocess
import time
from pathlib import Path

root = Path('/private/tmp/otbn-cov-selected-flags-20260928')
repo = Path(__file__).resolve().parents[4]
log = Path('/private/tmp/otbn-wide-selected-20260928.log')
output = Path('/private/tmp/otbn-wide-selected-20260928.vvp')
source_log = (root / 'matrix-compile.log').read_text()
original = next(line.removeprefix('command: ') for line in source_log.splitlines()
                if line.startswith('command: '))
command = shlex.split(original)
command[command.index('-o') + 1] = str(output)
command[command.index('-c') + 1] = str(root / 'matrix-iverilog.scr')
tracked = [root / 'matrix-iverilog.scr',
           root / 'sim-icarus/lowrisc_dv_otbn_sim_0.1.scr',
           root / 'src/lowrisc_dv_otbn_env_0.1/otbn_env_cov.sv',
           root / 'src/lowrisc_dv_otbn_sim_0.1/tb.sv',
           root / 'src/lowrisc_ip_otbn_tracer_0/rtl/otbn_trace_if.sv']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

before = {str(path): digest(path) for path in tracked}
start = time.monotonic()
result = subprocess.run(command, cwd=root / 'sim-icarus',
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        text=True, timeout=180)
elapsed = time.monotonic() - start
log.write_text(result.stdout)
after = {str(path): digest(path) for path in tracked}
evidence = {
    'pinned_source_commit': 'a78922f14a8cc20c7ee569f322a04626f2ac6127',
    'selected_copied_source_root': str(root),
    'overlay_dependency': ('Two mnemonic/CSR bin-source macros changed to localparams; '
                           'flag-group selection scalarized at ten sample calls; '
                           'one tracer assignment moved after its packed-struct declaration. '
                           'This is a diagnostic selected profile, not pristine-source compile.'),
    'command': command,
    'cwd': str(root / 'sim-icarus'),
    'exit_code': result.returncode,
    'elapsed_seconds': round(elapsed, 3),
    'log': str(log),
    'log_sha256': digest(log),
    'output': str(output),
    'dropped_wide_bins': result.stdout.count('runtime range expression that cannot be represented; the bin is dropped'),
    'hard_error_lines': [line for line in result.stdout.splitlines()
                         if ': error:' in line or ': internal error:' in line],
    'source_hashes_before': before,
    'source_hashes_after': after,
    'source_hashes_unchanged': before == after,
    'compiler_binary_sha256': digest(repo / 'local-install/bin/iverilog'),
    'simulator_binary_sha256': digest(repo / 'local-install/bin/vvp'),
    'compiler_git_head_at_compile': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
    'compiler_worktree_diff_sha256': hashlib.sha256(subprocess.check_output(
        ['git', 'diff', '--', 'elaborate.cc', 'vvp/vthread.cc'],
        cwd=repo)).hexdigest(),
    'warning_lines': [line for line in result.stdout.splitlines()
                      if ': warning:' in line],
}
path = Path(__file__).resolve().with_name('selected_compile_evidence.json')
path.write_text(json.dumps(evidence, indent=2) + '\n')
print(json.dumps({key: evidence[key] for key in ('exit_code', 'elapsed_seconds',
      'dropped_wide_bins', 'hard_error_lines', 'source_hashes_unchanged', 'log',
      'log_sha256')}, indent=2))
