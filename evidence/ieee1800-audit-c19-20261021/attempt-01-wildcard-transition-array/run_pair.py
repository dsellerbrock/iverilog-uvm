#!/usr/bin/env python3
from pathlib import Path
import subprocess
import tempfile

root = Path.cwd()
evidence = Path(__file__).resolve().parent
install = Path('/tmp/a3-ieee1800-c19-20261021-install')
sources = {
    'arrayed': evidence / 'input/p19_05_04_wildcard_transition_array.sv',
    'scalar-control': root / 'ivtest/ivltests/sv_covergroup_wildcard_transition.v',
}
rows = ['case\tedition\tcompile_exit\tbin_dropped_diagnostic\trun_exit']
with tempfile.TemporaryDirectory(prefix='a3-c19-arrayed-') as td:
    for case, source in sources.items():
        for edition in ('2017', '2023'):
            output = Path(td) / f'{case}-{edition}.vvp'
            compile_cmd = [str(install / 'bin/iverilog'), '-B', str(install / 'lib/ivl'), f'-g{edition}', '-s', source.stem, '-o', str(output), str(source)]
            compiled = subprocess.run(compile_cmd, cwd=root, text=True, capture_output=True, timeout=30)
            for stream in ('stdout', 'stderr'):
                (evidence / f'{case}-{edition}.compile.{stream}').write_text(getattr(compiled, stream))
            run_code = 'not-run'
            if compiled.returncode == 0:
                ran = subprocess.run([str(install / 'bin/vvp'), str(output)], cwd=root, text=True, capture_output=True, timeout=30)
                run_code = str(ran.returncode)
                for stream in ('stdout', 'stderr'):
                    (evidence / f'{case}-{edition}.run.{stream}').write_text(getattr(ran, stream))
            dropped = 'wildcard arrayed transition bin' in compiled.stderr and 'bin is dropped' in compiled.stderr
            rows.append(f'{case}\t{edition}\t{compiled.returncode}\t{str(dropped).lower()}\t{run_code}')
(evidence / 'status.tsv').write_text('\n'.join(rows) + '\n')
print('\n'.join(rows))
