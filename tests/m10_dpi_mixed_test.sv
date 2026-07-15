// M10: DPI argument marshaling — mixed types, widths, and counts.
// Every check exercises a signature the pre-M10 runtime miscompiled
// (mixed int/real ABI, >32-bit integers, byte/shortint widths,
// >8 arguments, real functions with 3+ args, void with mixed args).
module m10_dpi_mixed_test;

  import "DPI-C" function real c_mix_ir(int a, real b);
  import "DPI-C" function int c_mix_ri(real a, int b);
  import "DPI-C" function real c_mix_iris(int a, real b, int c, string d);
  import "DPI-C" function longint c_add64(longint a, longint b);
  import "DPI-C" function int c_widths(byte b, shortint h, int i, longint l);
  import "DPI-C" function int c_uwidths(byte unsigned b, shortint unsigned h,
                                        int unsigned i);
  import "DPI-C" function chandle c_make_handle(int tag);
  import "DPI-C" function int c_read_handle(chandle h);
  import "DPI-C" function int c_sum12(int a1, int a2, int a3, int a4,
                                      int a5, int a6, int a7, int a8,
                                      int a9, int a10, int a11, int a12);
  import "DPI-C" function real c_avg3(real a, real b, real c);
  import "DPI-C" function void c_note(int code, string what, real val);
  import "DPI-C" function int c_note_count();
  import "DPI-C" function int c_logic_scalar(logic v);

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  chandle h;
  real r;
  longint l;
  int i;
  logic lz;

  initial begin
    // Mixed int/real in both orders: the pre-M10 switch passed reals
    // through integer registers (ABI break).
    r = c_mix_ir(7, 2.5);
    check("mix_ir", r == 7.0 * 2.5);
    i = c_mix_ri(1.5, 20);
    check("mix_ri", i == 30);

    // Four-arg mix including a string.
    r = c_mix_iris(3, 0.5, 4, "xyz");
    check("mix_iris", r == (3 + 0.5 + 4 + 3));

    // 64-bit arguments and return.
    l = c_add64(64'h1_0000_0000, 64'h2_0000_0005);
    check("add64", l == 64'h3_0000_0005);
    l = c_add64(-64'd5000000000, 64'd1);
    check("add64_neg", l == -64'd4999999999);

    // Sub-word widths: byte/shortint must arrive sign-extended.
    i = c_widths(-2, -300, 100000, -64'd40_0000_0000);
    check("widths_signed", i == 1);
    i = c_uwidths(8'hFF, 16'hFFFF, 32'hFFFF_FFFF);
    check("widths_unsigned", i == 1);

    // chandle round trip (pointer-width integer).
    h = c_make_handle(42);
    check("handle_nonnull", h != null);
    i = c_read_handle(h);
    check("handle_read", i == 42);

    // More than 8 arguments (pre-M10 cap).
    i = c_sum12(1,2,3,4,5,6,7,8,9,10,11,12);
    check("sum12", i == 78);

    // Real function with 3 args (pre-M10 dispatched through a 4-arg
    // cast — undefined behavior).
    r = c_avg3(1.0, 2.0, 6.0);
    check("avg3", r == 3.0);

    // void return with mixed args.
    c_note(5, "hello", 1.25);
    c_note(6, "world", 2.50);
    check("void_mixed", c_note_count() == 2);

    // svLogic scalar encoding: 0/1 pass through, X and Z arrive as
    // the svdpi encodings (sv_z=2, sv_x=3).
    lz = 1'b1;
    check("logic_1", c_logic_scalar(lz) == 1);
    lz = 1'b0;
    check("logic_0", c_logic_scalar(lz) == 0);
    lz = 1'bz;
    check("logic_z", c_logic_scalar(lz) == 2);
    lz = 1'bx;
    check("logic_x", c_logic_scalar(lz) == 3);

    if (fail_count == 0)
      $display("M10 DPI MIXED TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M10 DPI MIXED TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
