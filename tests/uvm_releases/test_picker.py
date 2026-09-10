"""Exercise release selection without requiring any full UVM library."""
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
base = str(Path(sys.argv[2]).resolve())
with tempfile.TemporaryDirectory(prefix='uvm picker ') as directory:
    root = Path(directory)
    catalog = root / 'releases'
    for version, marker in [('1.2', 'OLD_RELEASE'), ('2020.3.1', 'NEW_RELEASE')]:
        source = catalog / version / 'src'
        source.mkdir(parents=True)
        (source / 'uvm_pkg.sv').write_text(f'package {marker}; endpackage\n')
    (catalog / 'incomplete').mkdir()
    (catalog / 'flat').mkdir()
    (catalog / 'flat/uvm_pkg.sv').write_text('package FLAT_RELEASE; endpackage\n')
    source = root / 'test.sv'
    source.write_text('module test; endmodule\n')
    env = dict(os.environ, IVERILOG_UVM_RELEASES=str(catalog))
    env.pop('IVERILOG_UVM_HOME', None)
    def run(*args, extra=None):
        return subprocess.run([compiler, '-B', base, *args], env=env | (extra or {}),
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    listed = run('--uvm-list')
    assert listed.returncode == 0, listed.stderr
    assert set(listed.stdout.splitlines()) == {'1.2', '2020.3.1', 'flat'}, listed.stdout
    for version, marker in [('1.2', 'OLD_RELEASE'), ('2020.3.1', 'NEW_RELEASE')]:
        result = run('--uvm=' + version, '-E', '-o', '-', str(source))
        assert result.returncode == 0 and marker in result.stdout, result
    flat = run('--uvm=flat', '-E', '-o', '-', str(source))
    assert flat.returncode == 0 and 'FLAT_RELEASE' in flat.stdout, flat
    default_base = root / 'base'
    shutil.copytree(catalog, default_base / 'uvm/releases')
    default = run('-B', str(default_base), '--uvm-list',
                  extra={'IVERILOG_UVM_RELEASES': ''})
    assert default.returncode == 0 and set(default.stdout.splitlines()) == {'1.2', '2020.3.1', 'flat'}, default
    config = root / 'preserve.config'
    config.write_text('existing config')
    assert run('--uvm-list', extra={'IVERILOG_ICONFIG': str(config)}).returncode == 0
    assert config.read_text() == 'existing config'
    result = run('--uvm=1.2', '-E', '-o', '-', str(source),
                 extra={'IVERILOG_UVM_HOME': '/nonexistent'})
    assert result.returncode == 0 and 'OLD_RELEASE' in result.stdout, result
    for version in ['', '../1.2', '.', 'missing', 'incomplete']:
        result = run('--uvm=' + version, '-E', '-o', '-', str(source))
        assert result.returncode != 0 and 'UVM release' in result.stderr, result
    for options in [('--uvm=1.2', '--uvm-home=' + str(catalog / '1.2')),
                    ('--uvm-home', str(catalog / '1.2'), '--uvm=1.2')]:
        result = run(*options, '-E', '-o', '-', str(source))
        assert result.returncode != 0 and 'cannot combine' in result.stderr, result
    home = run('--uvm-home', str(catalog / '1.2'), '-E', '-o', '-', str(source))
    assert home.returncode == 0 and 'OLD_RELEASE' in home.stdout, home
    assert 'UVM' in run('--uvm-version').stdout
    assert run('--uvm-list', extra={'IVERILOG_UVM_RELEASES': str(root / 'absent')}).returncode == 0
print('PASS: UVM release selection, listing, diagnostics and existing options')
