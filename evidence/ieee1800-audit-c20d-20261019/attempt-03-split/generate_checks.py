from pathlib import Path
import re

src = Path('tests/1800_audit/c20/p20_08a_math_bits.sv').read_text()
start = src.index('initial begin') + len('initial begin')
prefix = src[:start]
calls = []
pos = 0
while True:
    at = src.find('ck("', pos)
    if at < 0:
        break
    name = re.match(r'ck\("([A-Za-z0-9_]+)"', src[at:]).group(1)
    open_paren = at + 2
    depth = 0
    in_string = False
    escaped = False
    end = None
    for i in range(open_paren, len(src)):
        ch = src[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise ValueError(f'unclosed check: {name}')
    calls.append((name, src[at:end]))
    pos = end
assert len(calls) == 17, len(calls)
assert len({name for name, _ in calls}) == len(calls)
header = prefix + '\n $display("RESULT pass=%0d fail=%0d",p,f); end endmodule\n'
(Path('tests/1800_audit/c20/s/s_header.sv')).write_text(header)
for name, call in calls:
    setup = "ctl[0]=1'bx; ctl[1]=1'bz; " if name == 'var_ctl' else ''
    content = prefix + '\n ' + setup + call + ';\n $display("RESULT pass=%0d fail=%0d",p,f); end endmodule\n'
    Path(f'tests/1800_audit/c20/s/s_{name}.sv').write_text(content)
print(f'generated {len(calls)} individual checks plus header')
