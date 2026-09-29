// Part selects of whole vector signals are read without loading the whole
// signal first, and single-word index and signed-compare operands take a
// word-level path. Neither may change a value (IEEE 1800-2017/2023 7.4.6,
// 11.4.4, 11.5.1): out-of-range bits of a 4-state select are x, an x/z base
// selects all x, and forced bits are read through the force.
module test;
  logic [199:0] v;
  logic [199:0] v2;
  logic [99:0] src;
  wire [99:0] n;
  bit [99:0] bv;
  logic [15:0] zv;
  logic [7:0] r;
  bit [7:0] br;
  integer failed = 0;

  assign n = src;

  // Reference select built from shifts, which do not use part selects.
  function automatic logic [7:0] ref_up(input logic [199:0] vv,
                                        input longint b, input int size);
    logic [199:0] t;
    for (int k = 0; k < 8; k++) begin
      longint idx = b + k;
      if (idx < 0 || idx >= size) ref_up[k] = 1'bx;
      else begin
        t = vv >> idx;
        ref_up[k] = ^(t & 200'd1);
      end
    end
  endfunction

  function automatic logic [7:0] auto_sel(input logic [99:0] in, input int b);
    logic [99:0] av;
    av = in;
    return av[b +: 8];
  endfunction

  task automatic check(input string what, input logic [7:0] got,
                       input logic [7:0] exp);
    if (got !== exp) begin
      $display("FAILED: %s got %b expected %b", what, got, exp);
      failed++;
    end
  endtask

  initial begin : run
    int b;
    longint lb;
    logic [63:0] ub;
    logic signed [63:0] sb64;
    logic [69:0] wb;
    logic signed [32:0] s33;
    logic signed [0:0] s1;
    integer xb;
    logic [199:0] exp;
    logic signed [7:0] s8;
    logic signed [63:0] a64, c64;
    logic signed [64:0] a65;

    for (int k = 0; k < 200; k++) v[k] = ((k * 7 + 3) % 5) < 2;
    for (int k = 0; k < 200; k++) v2[k] = ((k * 3 + 1) % 4) == 0;
    for (int k = 0; k < 100; k++) src[k] = ((k * 5 + 2) % 3) == 0;
    for (int k = 0; k < 100; k++) bv[k] = (k % 7) < 3;

    // Dynamic in-range, partial and out-of-range bases, both directions.
    for (b = -12; b < 212; b++) begin
      check("up", v[b +: 8], ref_up(v, b, 200));
      check("down", v[b -: 8], ref_up(v, b - 7, 200));
    end

    // Base widths around and beyond one word.
    s1 = 1'b1;           // -1
    check("s1", v[s1 +: 8], ref_up(v, -1, 200));
    s33 = -33'sd3;
    check("s33", v[s33 +: 8], ref_up(v, -3, 200));
    sb64 = -64'sd1;
    check("s64 -1", v[sb64 +: 8], ref_up(v, -1, 200));
    sb64 = 64'sh8000_0000_0000_0000;
    check("s64 min", v[sb64 +: 8], 8'bx);
    ub = 64'hffff_ffff_ffff_fff0;
    check("u64 top", v[ub +: 8], 8'bx);
    ub = 64'd192;
    check("u64 192", v[ub +: 8], ref_up(v, 192, 200));
    wb = 70'd1 << 65;
    check("70-bit", v[wb +: 8], 8'bx);
    wb = 70'd96;
    check("70-bit 96", v[wb +: 8], ref_up(v, 96, 200));
    lb = 64'sd190;
    check("longint", v[lb +: 8], ref_up(v, 190, 200));

    // An x or z base selects all x.
    xb = 'x;
    check("x base", v[xb +: 8], 8'bx);
    xb = 32'bz;
    check("z base", v[xb +: 8], 8'bx);

    // Constant bases.
    check("const lo", v[10 +: 8], ref_up(v, 10, 200));
    check("const hi", v[199 -: 8], ref_up(v, 192, 200));

    // x and z data bits are selected as they are.
    zv = 16'bzzzz_xxxx_1010_0101;
    b = 4;
    check("xz data", zv[b +: 8], 8'bxxxx_1010);
    b = 8;
    check("xz data hi", zv[b +: 8], 8'bzzzz_xxxx);

    // Forced bits of a net are read through the force.
    #1;
    force n[20:10] = 11'h7ff;
    #1;
    exp = 200'(src);
    exp[20:10] = '1;
    for (b = 0; b < 100; b++)
      check("forced net", n[b +: 8], ref_up(exp, b, 100));
    release n[20:10];
    #1;
    for (b = 0; b < 100; b++)
      check("released net", n[b +: 8], ref_up(200'(src), b, 100));

    // A forced variable is read through the force; after release it keeps
    // the forced value until it is assigned again.
    force v2 = v;
    #1;
    for (b = 0; b < 200; b++)
      check("forced var", v2[b +: 8], ref_up(v, b, 200));
    release v2;
    #1;
    for (b = 0; b < 200; b++)
      check("released var", v2[b +: 8], ref_up(v, b, 200));

    // A two-state source, in range. (Out-of-range bits assigned to a
    // two-state destination are a separate recorded defect.)
    for (b = 0; b <= 92; b++) begin
      br = bv[b +: 8];
      if (br !== 8'(bv >> b)) begin
        $display("FAILED: 2-state b=%0d got %b expected %b", b, br, 8'(bv >> b));
        failed++;
      end
    end

    // An automatic variable.
    for (b = -4; b < 100; b++)
      check("automatic", auto_sel(src, b), ref_up(200'(src), b, 100));

    // Signed compares, variable and immediate, at word boundaries.
    s8 = -8'sd128;
    if (!(s8 < 8'sd127) || (s8 > -8'sd1) || !(s8 < -8'sd1) || (s8 != -8'sd128))
      begin $display("FAILED: s8 compare"); failed++; end
    a64 = 64'sh8000_0000_0000_0000;
    c64 = 64'sh7fff_ffff_ffff_ffff;
    if (!(a64 < c64) || (c64 < a64) || !(a64 < 0) || (c64 < 0) || !(a64 <= a64))
      begin $display("FAILED: 64-bit compare"); failed++; end
    a65 = -65'sd5;
    if (!(a65 < 65'sd3) || !(a65 >= -65'sd5) || (a65 > -65'sd6 == 0))
      begin $display("FAILED: 65-bit compare"); failed++; end
    for (int j = -3; j < 50; j++) begin
      if ((j < 46) !== (j <= 45) || (j < 0) !== (j <= -1))
        begin $display("FAILED: int compare j=%0d", j); failed++; end
    end
    xb = 'x;
    if ((xb < 5) !== 1'bx)
      begin $display("FAILED: x compare"); failed++; end

    if (failed == 0) $display("PASSED");
    $finish;
  end
endmodule
