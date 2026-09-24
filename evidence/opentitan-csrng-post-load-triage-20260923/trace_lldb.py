"""Read-only LLDB breakpoint callbacks for a bounded VVP concat identity trace."""

import collections
import json
import os
import struct

OUTPUT = os.environ["CSRNG_CONCAT_TRACE_OUT"]
LIMIT = int(os.environ.get("CSRNG_CONCAT_TRACE_LIMIT", "5000"))
FUNCTORS = {}
COUNTS = collections.Counter()
VALUES = collections.defaultdict(lambda: collections.Counter())
TOTAL = 0


def _reg(frame, name):
    return frame.FindRegister(name).GetValueAsUnsigned()


def on_compile(frame, _bp_loc, _dict):
    # compile_concat8+220: x21 is label, x22 the newly constructed functor,
    # and x23 its output net, immediately before define_functor_symbol.
    process = frame.GetThread().GetProcess()
    label = process.ReadCStringFromMemory(_reg(frame, "x21"), 512, __import__("lldb").SBError())
    FUNCTORS[_reg(frame, "x22")] = {"label": label, "net": _reg(frame, "x23")}
    return False


def on_run(frame, _bp_loc, _dict):
    global TOTAL
    TOTAL += 1
    pointer = _reg(frame, "x0")
    COUNTS[pointer] += 1
    if pointer in FUNCTORS:
        process = frame.GetThread().GetProcess()
        err = __import__("lldb").SBError()
        vec = process.ReadMemory(pointer + 0x20, 16, err)
        if err.Success() and len(vec) == 16:
            width = struct.unpack_from("<I", vec)[0]
            if width <= 8:
                data = vec[8:8 + width]
            elif width <= 512:
                addr = struct.unpack_from("<Q", vec, 8)[0]
                data = process.ReadMemory(addr, width, err)
            else:
                data = b""
            if err.Success():
                VALUES[pointer][data.hex()] += 1
    if TOTAL < LIMIT:
        return False
    rows = []
    for pointer, count in COUNTS.most_common():
        rows.append({"functor_pointer": hex(pointer), "hits": count,
                     "compile_record": FUNCTORS.get(pointer),
                     "distinct_values": len(VALUES[pointer]),
                     "top_values": VALUES[pointer].most_common(5)})
    with open(OUTPUT, "w", encoding="utf-8") as stream:
        json.dump({"limit": LIMIT, "compiled_concat8": len(FUNCTORS),
                   "unique_runtime_concat8": len(COUNTS), "top": rows[:40]},
                  stream, indent=2)
        stream.write("\n")
    return True
