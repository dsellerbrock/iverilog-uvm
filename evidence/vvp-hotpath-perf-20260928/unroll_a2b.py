#!/usr/bin/env python3
"""Write a manually unrolled DIAGNOSTIC copy of abr_masked_A2B_conv.sv.

Upper-bound experiment only: it removes the automatic for-init index `j`
and is not an RTL workaround. Run in a disposable directory holding a copy
of the pinned file:
  python3 unroll_a2b.py abr_masked_A2B_conv.sv > abr_masked_A2B_conv_unrolled.sv
"""
import sys
W = 46
s = open(sys.argv[1]).read()
end = "                    end\n                end\n            end\n"
def cut(s, head):
    a = s.index(head)
    b = s.index(end, a) + len("                    end\n")
    return s[a:b]
xy = []
for j in range(W):
    if j == 0:
        xy.append("                    x_reg[i][0] <= {rnd_for_Boolean0[i], (x[i][0] ^ rnd_for_Boolean0[i])};")
        xy.append("                    y_reg[i][0] <= {rnd_for_Boolean1[i], (x[i][1] ^ rnd_for_Boolean1[i])};")
    else:
        xy.append(f"                    x_reg[i][{j}] <= x_reg[i][{j-1}];")
        xy.append(f"                    y_reg[i][{j}] <= y_reg[i][{j-1}];")
s = s.replace(cut(s, "                    for (int j = 0; j < WIDTH; j = j + 1) begin"), "\n".join(xy) + "\n", 1)
sm = []
for j in range(W):
    b = (f"                    if ({j} == i && i == WIDTH-1) sum_reg[i][{j}] <= the_last_sum;\n"
         f"                    else if ({j} == i) sum_reg[i][{j}] <= sum[i];")
    if j > 0:
        b += f"\n                    else if ({j} > i) sum_reg[i][{j}] <= sum_reg[i][{j-1}];"
    sm.append(b)
s = s.replace(cut(s, "                    for (int j = i; j < WIDTH; j = j + 1) begin"), "\n".join(sm) + "\n", 1)
sys.stdout.write(s)
