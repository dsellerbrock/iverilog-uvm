#!/usr/bin/env python3
"""Spike: translate always-block threads of a .vvp file to 4-state C++.

usage: native_gen4.py in.vvp out.vvp out.cc

A thread qualifies when it is  T_n ; %wait E; <body> ; %jmp T_n;. Its body
is translated to a function whose values are 4-state words: every stack
slot of at most 64 bits is a pair of a/b bit planes in vvp_vector4_t's
encoding (0=00 1=10 z=01 x=11 as ab), and every operation reproduces the
interpreter handler's x/z rules word-wide. Every side effect (loads,
stores, NBAs, index registers) runs through vvp's handlers or equivalent
helpers, in program order.

The function hands the thread back to the interpreter ("deoptimizes") at an
instruction it does not translate (an unknown opcode, a value wider than 64
bits, a backward jump): it pushes its stack and flags into the thread and
returns that instruction, and the interpreter runs it and the rest of the
body. Everything before has had exactly the bytecode's effects, so resuming
is exact.
"""
import os, re, sys

src, dst, out_cc = sys.argv[1:4]
lines = open(src).read().split('\n')

# Net and array word widths from .var/.net/.array declarations.
widths = {}
for ln in lines:
    m = re.match(r'(\S+) \.(var|net)\S* "[^"]*", (-?\d+) (-?\d+)', ln)
    if m:
        widths[m.group(1)] = abs(int(m.group(3)) - int(m.group(4))) + 1
    m = re.match(r'(\S+) \.array\S* "[^"]*", -?\d+ -?\d+, (-?\d+) (-?\d+)', ln)
    if m:
        widths[m.group(1)] = abs(int(m.group(2)) - int(m.group(3))) + 1


def args_of(ins):
    parts = ins.split(';', 1)[0].split(None, 1)
    op = parts[0]
    a = [x.strip() for x in parts[1].split(',')] if len(parts) > 1 else []
    return op, a


def mask(w):
    return '0xffffffffffffffffULL' if w == 64 else '0x%xULL' % ((1 << w) - 1)


def sext(v, w):
    return '((uint64_t)((int64_t)((%s) << %d) >> %d))' % (v, 64 - w, 64 - w)


def A(i):
    return 'a%d' % i


def B(i):
    return 'b%d' % i


class Reject(Exception):
    pass


# The flag codes are the vvp_bit4_t values: 0, 1, 2 (z), 3 (x).
PRELUDE = r'''
static inline unsigned char bit4_not_(unsigned char f) { f ^= 1; return f == 2 ? 3 : f; }
static inline unsigned char bit4_or_(unsigned char x, unsigned char y)
{ if (x == 1 || y == 1) return 1; unsigned char r = x | y; return r == 2 ? 3 : r; }
'''


def translate(idx, body):
    """body: list of ('label', name) or ('ins', ordinal, text)."""
    ninstr = sum(1 for b in body if b[0] == 'ins')
    body_labels = set(b[1] for b in body if b[0] == 'label')
    label_state = {}           # label -> stack widths expected on entry
    seen_labels = set()
    out = []
    stack = []                 # widths of the live stack slots
    flags_read, flags_written = set(), set()
    st = {'reachable': True, 'maxdepth': 0}
    deopts = []

    def deopt(k, depth=None):
        live = stack if depth is None else stack[:depth]
        push = ''.join('vvp_native_push(thr, %s, %s, %d); ' % (A(i), B(i), w)
                       for i, w in enumerate(live))
        return '{ %sFLUSH; DSTAT(%d); return C[%d]; }' % (push, k, k)

    def jump_to(lbl):
        if lbl not in body_labels:
            raise Reject('jump out of body')
        if lbl in seen_labels:
            raise Reject('backward jump')
        want = tuple(stack)
        if label_state.setdefault(lbl, want) != want:
            raise Reject('stack mismatch at ' + lbl)
        return 'goto %s;' % lbl.replace('.', '_')

    def imm(a):                # %op vala, valb, wid: a/b planes of the immediate
        vala, valb, wid = int(a[0]), int(a[1]), int(a[2])
        if wid > 64 or wid == 0:
            raise Reject('immediate width %d' % wid)
        m = (1 << wid) - 1
        return '%dULL' % (vala & m), '%dULL' % (valb & m), wid

    def need(n):
        if len(stack) < n:
            raise Reject('stack underflow')

    def grow(w):
        if w > 64 or w == 0:
            raise Reject('width %d' % w)
        stack.append(w)
        st['maxdepth'] = max(st['maxdepth'], len(stack))
        return len(stack) - 1

    def push(w, aexpr, bexpr, pre=''):
        """Push a w-bit value. The expressions may read any slot (they are
        evaluated into temporaries before the slot is written)."""
        i = grow(w)
        out.append('    { %suint64_t na_ = %s, nb_ = %s; %s = na_ & %s; %s = nb_ & %s; }'
                   % (pre, aexpr, bexpr, A(i), mask(w), B(i), mask(w)))

    def push_code(expr_code):
        """Push a 1-bit value from a flag-code expression."""
        push(1, '(uint64_t)((%s) & 1)' % expr_code, '(uint64_t)((%s) >> 1)' % expr_code,
             pre='')

    def push_loaded(w, call, k):
        i = grow(w)
        out.append('    if (!%s) %s' % (call % ('&' + A(i), '&' + B(i)), deopt(k, i)))

    def flag(f):
        f = int(f)
        flags_read.add(f)
        return 'f%d' % f

    def set_flag(f, expr):
        f = int(f)
        flags_written.add(f)
        out.append('    f%d = %s;' % (f, expr))

    def binop(op, la, lb, ra, rb, w):
        m = mask(w)
        if op == '%and':
            return ('((%s | %s) & (%s | %s))' % (la, lb, ra, rb),
                    '(((%s | %s) & %s) | ((%s | %s) & %s))' % (la, lb, rb, ra, rb, lb))
        if op == '%or':
            return ('(%s | %s | %s | %s)' % (la, lb, ra, rb),
                    '(((~%s | %s) & %s) | ((~%s | %s) & %s))' % (la, lb, rb, ra, rb, lb))
        if op == '%xor':
            return ('((%s ^ %s) | %s | %s)' % (la, ra, lb, rb), '(%s | %s)' % (lb, rb))
        if op in ('%add', '%sub', '%mul'):
            c = {'%add': '+', '%sub': '-', '%mul': '*'}[op]
            xz = '(((%s | %s) & %s) != 0)' % (lb, rb, m)
            return ('(%s ? %s : (%s %s %s))' % (xz, m, la, c, ra),
                    '(%s ? %s : 0)' % (xz, m))
        raise Reject('binop ' + op)

    def inv(a_, b_):
        return '(~(%s) | (%s))' % (a_, b_), b_

    def one(k, op, a):
        top = len(stack) - 1
        cut = os.environ.get('NATIVE_CUT')          # debug: "fn:k"
        if cut and int(cut.split(':')[0]) == idx and k >= int(cut.split(':')[1]):
            raise Reject('cut')
        if op == '%pushi/vec4':
            va, vb, w = imm(a)
            push(w, va, vb)
        elif op == '%load/vec4':
            w = widths.get(a[0])
            if w is None:
                raise Reject('unknown net')
            push_loaded(w, 'vvp_native_read(C[%d], %%s, %%s)' % k, k)
        elif op == '%load/vec4/parti':
            push_loaded(int(a[1]), 'vvp_native_read_part(thr, C[%d], %%s, %%s)' % k, k)
        elif op == '%load/vec4a':
            w = widths.get(a[0])
            if w is None:
                raise Reject('unknown array')
            out.append('    vvp_native_set_flag(thr, 4, %s);' % flag(4))
            push_loaded(w, 'vvp_native_load(thr, C[%d], %%s, %%s)' % k, k)
        elif op == '%ix/load':
            out.append('    vvp_native_exec(thr, C[%d]);' % k)
        elif op in ('%ix/vec4', '%ix/vec4/s'):
            need(1)
            w = stack.pop()
            v = sext(A(top), w) if op.endswith('/s') else A(top)
            out.append('    if (%s) { vvp_native_set_word(thr, %s, 0); f4 = 1; }'
                       ' else { vvp_native_set_word(thr, %s, (int64_t)%s); f4 = 0; }'
                       % (B(top), a[0], a[0], v))
            flags_written.add(4)
        elif op == '%store/vec4':
            need(1)
            if a[1] != '0':
                raise Reject('indexed store')
            w = int(a[2])
            if widths.get(a[0]) is None or stack[-1] < w or w > 64:
                raise Reject('store width')
            out.append('    vvp_native_store_net(thr, C[%d], %s & %s, %s & %s, %d);'
                       % (k, A(top), mask(w), B(top), mask(w), w))
            stack.pop()
        elif op in ('%assign/vec4', '%assign/vec4/a/d', '%assign/vec4/off/d'):
            # The handler sees exactly the value the interpreter would push.
            need(1)
            if op != '%assign/vec4':
                out.append('    vvp_native_set_flag(thr, 4, %s);' % flag(4))
            out.append('    vvp_native_store(thr, C[%d], %s, %s, %d);'
                       % (k, A(top), B(top), stack[-1]))
            stack.pop()
        elif op in ('%and', '%or', '%xor', '%add', '%sub', '%mul',
                    '%nand', '%nor', '%xnor'):
            need(2)
            if stack[-1] != stack[-2]:
                raise Reject('binary width mismatch')
            w = stack.pop()
            stack.pop()
            base = {'%nand': '%and', '%nor': '%or', '%xnor': '%xor'}.get(op, op)
            ea, eb = binop(base, A(top - 1), B(top - 1), A(top), B(top), w)
            if base != op:
                ea, eb = inv(ea, eb)
            push(w, ea, eb)
        elif op in ('%addi', '%subi', '%muli'):
            need(1)
            va, vb, w = imm(a)
            if stack[-1] != w:
                raise Reject('imm width mismatch')
            stack.pop()
            ea, eb = binop({'%addi': '%add', '%subi': '%sub', '%muli': '%mul'}[op],
                           A(top), B(top), va, vb, w)
            push(w, ea, eb)
        elif op == '%inv':
            need(1)
            w = stack.pop()
            ea, eb = inv(A(top), B(top))
            push(w, ea, eb)
        elif op == '%pad/u':
            need(1)
            stack.pop()
            push(int(a[0]), A(top), B(top))
        elif op == '%pad/s':
            need(1)
            w = stack.pop()
            push(int(a[0]), sext(A(top), w), sext(B(top), w))
        elif op == '%cast2':
            need(1)
            w = stack.pop()
            push(w, '(%s & ~%s)' % (A(top), B(top)), '0')
        elif op == '%replicate':
            need(1)
            n = int(a[0])
            w = stack.pop()
            if w * n > 64 or n == 0:
                raise Reject('wide replicate')
            rep = lambda v: '(' + ' | '.join('(%s << %d)' % (v, i * w) for i in range(n)) + ')'
            push(w * n, rep(A(top)), rep(B(top)))
        elif op == '%concat/vec4':
            need(2)
            wl = stack.pop()
            wm = stack.pop()
            if wl + wm > 64:
                raise Reject('wide concat')
            push(wl + wm, '((%s << %d) | %s)' % (A(top - 1), wl, A(top)),
                 '((%s << %d) | %s)' % (B(top - 1), wl, B(top)))
        elif op == '%concati/vec4':
            need(1)
            va, vb, wl = imm(a)
            wm = stack.pop()
            if wl + wm > 64:
                raise Reject('wide concat')
            push(wl + wm, '((%s << %d) | %s)' % (A(top), wl, va),
                 '((%s << %d) | %s)' % (B(top), wl, vb))
        elif op == '%split/vec4':
            need(1)
            lw = int(a[0])
            w = stack.pop()
            if lw == 0 or lw >= w:
                raise Reject('split width')
            out.append('    ta_ = %s; tb_ = %s;' % (A(top), B(top)))
            push(w - lw, 'ta_ >> %d' % lw, 'tb_ >> %d' % lw)
            push(lw, 'ta_', 'tb_')
        elif op in ('%shiftl', '%shiftr'):
            need(1)
            w = stack.pop()
            f4 = flag(4)
            c = '<<' if op == '%shiftl' else '>>'
            out.append('    ta_ = vvp_native_get_word(thr, %s);' % a[0])
            m = mask(w)
            push(w, '(%s == 1) ? %s : (%s == 3 || ta_ >= %d) ? 0 : (%s %s ta_)'
                 % (f4, m, f4, w, A(top), c),
                 '(%s == 1) ? %s : (%s == 3 || ta_ >= %d) ? 0 : (%s %s ta_)'
                 % (f4, m, f4, w, B(top), c))
        elif op == '%shiftr/s':
            # x/z shift amount: all x. Unknown (flag x) or >= width: all
            # sign bits. The sign-extended planes shift arithmetically.
            need(1)
            w = stack.pop()
            f4 = flag(4)
            m = mask(w)
            out.append('    ta_ = vvp_native_get_word(thr, %s); ta_ = (%s == 3 || ta_ > 63) ? 63 : ta_;'
                       % (a[0], f4))
            push(w, '(%s == 1) ? %s : (uint64_t)((int64_t)%s >> ta_)' % (f4, m, sext(A(top), w)),
                 '(%s == 1) ? %s : (uint64_t)((int64_t)%s >> ta_)' % (f4, m, sext(B(top), w)))
        elif op in ('%or/r', '%nor/r', '%and/r', '%xor/r'):
            need(1)
            w = stack.pop()
            a_, b_ = A(top), B(top)
            if op in ('%or/r', '%nor/r'):
                one_, zero_ = ('1', '0') if op == '%or/r' else ('0', '1')
                code = '((%s & ~%s) ? %s : %s ? 3 : %s)' % (a_, b_, one_, b_, zero_)
            elif op == '%and/r':
                code = '((~%s & ~%s & %s) ? 0 : %s ? 3 : 1)' % (a_, b_, mask(w), b_)
            else:
                code = '(%s ? 3 : (unsigned)__builtin_parityll(%s))' % (b_, a_)
            push_code(code)
        elif op in ('%cmp/u', '%cmpi/u', '%cmp/s', '%cmpi/s', '%cmp/e',
                    '%cmp/ne', '%cmpi/e', '%cmpi/ne'):
            if op.startswith('%cmpi'):
                need(1)
                ra, rb, rw = imm(a)
                lw = stack[-1]
                la, lb = A(top), B(top)
                npop = 1
            else:
                need(2)
                rw, lw = stack[-1], stack[-2]
                ra, rb, la, lb = A(top), B(top), A(top - 1), B(top - 1)
                npop = 2
            eeq = '(%s == %s && %s == %s)' % (la, ra, lb, rb)
            xz = '((%s | %s) != 0)' % (lb, rb)
            # eq: 0 on a mismatch of two defined bits, else x when any
            # bit is x/z, else 1.
            eq = ('(((%s ^ %s) & ~%s & ~%s) ? 0 : %s ? 3 : 1)'
                  % (la, ra, lb, rb, xz))
            if op in ('%cmp/s', '%cmpi/s'):
                if lw != rw:
                    raise Reject('signed compare width mismatch')
                out.append('    if (%s) { f4 = f5 = 3; f6 = %s; }'
                           ' else { int64_t l_ = %s, r_ = %s; f4 = f6 = l_ == r_; f5 = l_ < r_; }'
                           % (xz, eeq, sext(la, lw), sext(ra, rw)))
                flags_written.update((4, 5, 6))
            elif op in ('%cmp/u', '%cmpi/u'):
                out.append('    if (%s) { f4 = %s; f5 = 3; f6 = %s; }'
                           ' else { f4 = f6 = %s == %s; f5 = %s < %s; }'
                           % (xz, eq, eeq, la, ra, la, ra))
                flags_written.update((4, 5, 6))
            else:
                if op.endswith('ne'):
                    out.append('    f4 = bit4_not_(%s); f6 = !%s;' % (eq, eeq))
                else:
                    out.append('    f4 = %s; f6 = %s;' % (eq, eeq))
                flags_written.update((4, 6))
            for _ in range(npop):
                stack.pop()
        elif op == '%blend':
            need(2)
            if stack[-1] != stack[-2]:
                raise Reject('blend width mismatch')
            w = stack.pop()
            stack.pop()
            out.append('    ta_ = (%s ^ %s) | (%s ^ %s);'
                       % (A(top), A(top - 1), B(top), B(top - 1)))
            push(w, '%s | ta_' % A(top), '%s | ta_' % B(top))
        elif op == '%flag_set/imm':
            set_flag(a[0], str(int(a[1])))
        elif op == '%flag_mov':
            set_flag(a[0], flag(a[1]))
        elif op == '%flag_or':
            set_flag(a[0], 'bit4_or_(%s, %s)' % (flag(a[0]), flag(a[1])))
        elif op == '%flag_set/vec4':
            need(1)
            stack.pop()
            set_flag(a[0], '(unsigned char)((%s & 1) | ((%s & 1) << 1))' % (A(top), B(top)))
        elif op == '%flag_get/vec4':
            push_code(flag(a[0]))
        elif op == '%dup/vec4':
            need(1)
            push(stack[-1], A(top), B(top))
        elif op == '%pop/vec4':
            n = int(a[0])
            need(n)
            for _ in range(n):
                stack.pop()
        elif op == '%jmp':
            out.append('    ' + jump_to(a[0]))
            st['reachable'] = False
        elif op in ('%jmp/1', '%jmp/0', '%jmp/0xz'):
            f = flag(a[1])
            cond = {'%jmp/1': '%s == 1', '%jmp/0': '%s == 0',
                    '%jmp/0xz': '%s != 1'}[op] % f
            out.append('    if (%s) %s' % (cond, jump_to(a[0])))
        else:
            raise Reject('opcode ' + op)

    first_native = None
    for pos, item in enumerate(body):
        if item[0] == 'label':
            lbl = item[1]
            seen_labels.add(lbl)
            if lbl in label_state:
                want = label_state[lbl]
                if st['reachable'] and tuple(stack) != want:
                    # Fall through with a different stack: hand over to the
                    # interpreter at the next instruction.
                    nxt = next((b[1] for b in body[pos:] if b[0] == 'ins'), None)
                    if nxt is None:
                        raise Reject('stack mismatch at end')
                    out.append('    ' + deopt(nxt))
                    deopts.append('fallthrough mismatch')
                stack[:] = list(want)
                st['reachable'] = True
            elif not st['reachable']:
                continue
            out.append('%s:;' % lbl.replace('.', '_'))
            continue
        _, k, text = item
        if not st['reachable']:
            continue
        op, a = args_of(text)
        saved = (list(stack), len(out), set(flags_read), set(flags_written))
        out.append('    // %d: %s' % (k, text))
        try:
            one(k, op, a)
            if first_native is None:
                first_native = k
        except Reject as e:
            stack[:] = saved[0]
            del out[saved[1]:]
            flags_read.clear(); flags_read.update(saved[2])
            flags_written.clear(); flags_written.update(saved[3])
            if first_native is None:
                raise Reject('first instruction: %s (%s)' % (e, op))
            out.append('    // %d: %s  [interpreter: %s]' % (k, text, e))
            out.append('    ' + deopt(k))
            deopts.append('%s: %s' % (op, e))
            st['reachable'] = False
    if st['reachable'] and stack:
        raise Reject('stack not empty at end')

    # A flag written only on some paths keeps its old value on the others,
    # so every flag the body touches starts from the thread's value.
    flags_read |= flags_written
    flags = sorted(flags_read | {4, 5, 6})
    nslots = max(st['maxdepth'], 1)
    head = ['static vvp_code_t native_%d(vthread_t thr, vvp_code_t body)' % idx,
            '{',
            '    static vvp_code_t C[%d];' % max(ninstr, 1),
            '    static const char*const N_[] = { %s };' % ', '.join('"%s"' % args_of(b[2])[0] for b in body if b[0] == 'ins'),
            '    if (!C[0]) { vvp_code_t c = body; for (int i = 0; i < %d; i++) { C[i] = c; c = vvp_native_next(c); }' % ninstr,
            '      if (getenv("VVP_NATIVE_CHECK")) for (int i = 0; i < %d; i++) if (strcmp(vvp_native_opname(C[i]), N_[i])) { fprintf(stderr, "fn %d: C[%%d] is %%s, expected %%s\\n", i, vvp_native_opname(C[i]), N_[i]); break; } }' % (ninstr, idx),
            '    uint64_t ta_, tb_, %s;' % ', '.join('%s, %s' % (A(i), B(i)) for i in range(nslots)),
            '    unsigned char %s;' % ', '.join(
                'f%d = vvp_native_get_flag(thr, %d)' % (f, f) for f in flags),
            '#define DSTAT(k) dstat_note(%d, k)' % idx,
            '#define FLUSH %s' % ' '.join('vvp_native_set_flag(thr, %d, f%d);' % (f, f)
                                          for f in sorted(flags_written)),
            ]
    tail = ['    FLUSH;', '    return 0;', '#undef FLUSH', '#undef DSTAT', '}', '']
    return head + out + tail, deopts


# Find threads.
out_lines = list(lines)
inserts = []                  # (line_no, text) to insert before line_no
funcs = []
nthreads = 0
i = 0
while i < len(lines):
    m = re.match(r'(T_\d+) ;', lines[i])
    if not m:
        i += 1
        continue
    tname = m.group(1)
    j = i + 1
    while lines[j].strip().startswith('.scope'):
        j += 1
    if not lines[j].strip().startswith('%wait'):
        i += 1
        continue
    wait_line = j
    body = []
    k = 0
    end = None
    j += 1
    while j < len(lines):
        t = lines[j].strip()
        if t == '%%jmp %s;' % tname and lines[j + 1].strip().startswith('.thread %s' % tname):
            end = j
            break
        lm = re.match(r'(T_\d+\.\d+)\s*;', t)
        if lm:
            body.append(('label', lm.group(1)))
        elif t.startswith('%'):
            body.append(('ins', k, t))
            k += 1
        elif t.startswith('.scope') or t.startswith(';') or t == '':
            pass
        else:
            break
        j += 1
    nthreads += 1
    if end is None:
        print('%s: not a simple always thread (line %d: %s)' % (tname, j + 1, lines[j].strip()[:40]))
        i += 1
        continue
    idx = len(funcs)
    try:
        code, deopts = translate(idx, body)
    except Reject as e:
        print('%s: rejected (%s), %d instrs' % (tname, e, k))
        i = end
        continue
    funcs.append(code)
    inserts.append((wait_line + 1, '    %%native %d, NATIVE_%d;' % (idx, idx)))
    inserts.append((end, 'NATIVE_%d ;' % idx))
    print('%s: native_%d, %d instrs, %d static hand-overs %s'
          % (tname, idx, k, len(deopts), sorted(set(deopts))[:4]))
    i = end

for ln, text in sorted(inserts, reverse=True):
    out_lines.insert(ln, text)
open(dst, 'w').write('\n'.join(out_lines))

with open(out_cc, 'w') as f:
    f.write('// Generated by native_gen4.py (spike).\n#include <stdint.h>\n'
            '#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n')
    f.write('typedef struct vthread_s*vthread_t;\ntypedef struct vvp_code_s*vvp_code_t;\n')
    f.write('extern "C" {\n'
            'vvp_code_t vvp_native_next(vvp_code_t);\n'
            'const char* vvp_native_opname(vvp_code_t);\n'
            'bool vvp_native_read(vvp_code_t, uint64_t*, uint64_t*);\n'
            'bool vvp_native_read_part(vthread_t, vvp_code_t, uint64_t*, uint64_t*);\n'
            'bool vvp_native_load(vthread_t, vvp_code_t, uint64_t*, uint64_t*);\n'
            'void vvp_native_exec(vthread_t, vvp_code_t);\n'
            'unsigned vvp_native_get_flag(vthread_t, unsigned);\n'
            'void vvp_native_set_flag(vthread_t, unsigned, unsigned);\n'
            'void vvp_native_push(vthread_t, uint64_t, uint64_t, unsigned);\n'
            'uint64_t vvp_native_get_word(vthread_t, unsigned);\n'
            'void vvp_native_set_word(vthread_t, unsigned, int64_t);\n'
            'void vvp_native_store(vthread_t, vvp_code_t, uint64_t, uint64_t, unsigned);\n'
            'void vvp_native_store_net(vthread_t, vvp_code_t, uint64_t, uint64_t, unsigned);\n'
            '}\n'
            '#pragma GCC diagnostic ignored "-Wunused-variable"\n'
            '#pragma GCC diagnostic ignored "-Wunused-but-set-variable"\n'
            '#pragma GCC diagnostic ignored "-Wunused-label"\n'
            'static unsigned long dstat_[512][4096];\n'
            'static inline void dstat_note(int f, int k) { if (f < 512 && k < 4096) dstat_[f][k]++; }\n'
            '__attribute__((destructor)) static void dstat_dump() {\n'
            '  if (!getenv("VVP_NATIVE_STATS")) return;\n'
            '  for (int f = 0; f < 512; f++) for (int k = 0; k < 4096; k++)\n'
            '    if (dstat_[f][k] > 1000) fprintf(stderr, "deopt fn %d at %d: %lu\\n", f, k, dstat_[f][k]);\n'
            '}\n')
    f.write(PRELUDE)
    for code in funcs:
        f.write('\n'.join(code))
    f.write('typedef vvp_code_t (*fn_t)(vthread_t, vvp_code_t);\n')
    f.write('extern "C" {\nfn_t vvp_native_table[] = { %s };\n'
            % ', '.join('native_%d' % i for i in range(len(funcs))))
    f.write('unsigned vvp_native_count = %d;\n}\n' % len(funcs))
print('%d of %d threads translated' % (len(funcs), nthreads))
