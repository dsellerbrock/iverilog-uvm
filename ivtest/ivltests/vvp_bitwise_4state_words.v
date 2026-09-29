// The vvp %xor, %xnor, %nand and %nor instructions compute whole words at a
// time. Check every pair of operand bit values (0, 1, x, z) against the
// IEEE 1800-2017/2023 11.4.8 bitwise operator tables, at widths below, at
// and across the 64-bit word size. The binary ~& and ~| forms are an Icarus
// extension that compiles to %nand and %nor; they mean ~(a & b), ~(a | b).
module test;
  // Bit i of a and b hold operand values val[i/4] and val[i%4], with
  // val = {0, 1, x, z}, so the 16 bits cover all 16 operand pairs.
  reg [15:0] a, b;
  reg [15:0] r16;
  reg [63:0] r64;
  reg [79:0] r80;
  reg [127:0] r128;
  integer failed = 0;

  localparam [15:0] XOR  = 16'bxxxx_xxxx_xx01_xx10;
  localparam [15:0] XNOR = 16'bxxxx_xxxx_xx10_xx01;
  localparam [15:0] NAND = 16'bxxx1_xxx1_xx01_1111;
  localparam [15:0] NOR  = 16'bxx0x_xx0x_0000_xx01;

  task check16(input [15:0] got, input [15:0] want, input [8*8-1:0] name);
    if (got !== want) begin
      $display("FAILED %0s 16: got %b want %b", name, got, want);
      failed = failed + 1;
    end
  endtask

  task check64(input [63:0] got, input [63:0] want, input [8*8-1:0] name);
    if (got !== want) begin
      $display("FAILED %0s 64: got %b want %b", name, got, want);
      failed = failed + 1;
    end
  endtask

  task check80(input [79:0] got, input [79:0] want, input [8*8-1:0] name);
    if (got !== want) begin
      $display("FAILED %0s 80: got %b want %b", name, got, want);
      failed = failed + 1;
    end
  endtask

  task check128(input [127:0] got, input [127:0] want, input [8*8-1:0] name);
    if (got !== want) begin
      $display("FAILED %0s 128: got %b want %b", name, got, want);
      failed = failed + 1;
    end
  endtask

  initial begin
    a = 16'bzzzz_xxxx_1111_0000;
    b = 16'bzx10_zx10_zx10_zx10;

    r16 = a ^ b;     check16(r16, XOR, "xor");
    r16 = a ~^ b;    check16(r16, XNOR, "xnor");
    r16 = a ~& b;    check16(r16, NAND, "nand");
    r16 = a ~| b;    check16(r16, NOR, "nor");

    r64 = {4{a}} ^ {4{b}};     check64(r64, {4{XOR}}, "xor");
    r64 = {4{a}} ~^ {4{b}};    check64(r64, {4{XNOR}}, "xnor");
    r64 = {4{a}} ~& {4{b}};    check64(r64, {4{NAND}}, "nand");
    r64 = {4{a}} ~| {4{b}};    check64(r64, {4{NOR}}, "nor");

    r80 = {5{a}} ^ {5{b}};     check80(r80, {5{XOR}}, "xor");
    r80 = {5{a}} ~^ {5{b}};    check80(r80, {5{XNOR}}, "xnor");
    r80 = {5{a}} ~& {5{b}};    check80(r80, {5{NAND}}, "nand");
    r80 = {5{a}} ~| {5{b}};    check80(r80, {5{NOR}}, "nor");

    r128 = {8{a}} ^ {8{b}};     check128(r128, {8{XOR}}, "xor");
    r128 = {8{a}} ~^ {8{b}};    check128(r128, {8{XNOR}}, "xnor");
    r128 = {8{a}} ~& {8{b}};    check128(r128, {8{NAND}}, "nand");
    r128 = {8{a}} ~| {8{b}};    check128(r128, {8{NOR}}, "nor");

    // A result narrower than a word keeps no stray bits: widen it after
    // the operation and compare the upper bits.
    r80 = {64'd0, a ^ b};   check80(r80, {64'd0, XOR}, "xorpad");
    r80 = {64'd0, a ~^ b};  check80(r80, {64'd0, XNOR}, "xnorpad");

    if (failed == 0) $display("PASSED");
    $finish;
  end
endmodule
