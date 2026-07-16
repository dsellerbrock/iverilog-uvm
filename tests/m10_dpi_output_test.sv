// M10: DPI output/inout argument marshaling (35.5.6). The C side
// receives pointers; callee-written values must land back in the
// caller's actual lvalues. These are the shapes UVM's own DPI layer
// uses (e.g. `import "DPI-C" function bit uvm_re_compexecfree(string,
// string, bit, output int exec_ret)`).
module m10_dpi_output_test;

  import "DPI-C" function int c_divmod(int n, int d, output int quot,
                                       output int rem);
  import "DPI-C" function void c_stats(input real x, input real y,
                                       output real sum, output real prod);
  import "DPI-C" task c_swap64(inout longint a, inout longint b);
  import "DPI-C" function int c_step(inout int counter, input int delta);
  import "DPI-C" function void c_describe(input int code,
                                          output string text);
  import "DPI-C" function void c_flags(input byte v, output byte doubled,
                                       output shortint widened);
  import "DPI-C" function void c_bitop(input bit a, input bit b,
                                       output bit xr, output logic
                                       maybe);

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  int q, r, res, cnt;
  real s, p;
  longint a64, b64;
  string txt;
  byte db;
  shortint wd;
  bit xr;
  logic mb;

  initial begin
    // Two int outputs plus a return value.
    res = c_divmod(47, 5, q, r);
    check("divmod_ret", res == 1);
    check("divmod_quot", q == 9);
    check("divmod_rem", r == 2);

    // Real outputs.
    c_stats(2.5, 4.0, s, p);
    check("stats_sum", s == 6.5);
    check("stats_prod", p == 10.0);

    // Inout longint pair through an imported TASK.
    a64 = 64'h1111_2222_3333_4444;
    b64 = -64'd987654321012;
    c_swap64(a64, b64);
    check("swap_a", a64 == -64'd987654321012);
    check("swap_b", b64 == 64'h1111_2222_3333_4444);

    // Inout int: seeded with the current value, incremented in C.
    cnt = 100;
    res = c_step(cnt, 7);
    check("step_ret", res == 100);   // C returns the OLD value
    check("step_inout", cnt == 107);
    res = c_step(cnt, -7);
    check("step_ret2", res == 107);
    check("step_inout2", cnt == 100);

    // String output.
    c_describe(2, txt);
    check("describe", txt == "two");

    // byte/shortint outputs (sub-word pointer writes).
    c_flags(-5, db, wd);
    check("flags_byte", db == -10);
    check("flags_short", wd == -5);

    // 1-bit outputs: svBit and svLogic (X encoding comes back).
    c_bitop(1'b1, 1'b0, xr, mb);
    check("bit_xor", xr == 1'b1);
    check("logic_x_out", mb === 1'bx);
    c_bitop(1'b1, 1'b1, xr, mb);
    check("bit_xor2", xr == 1'b0);
    check("logic_1_out", mb === 1'b1);

    if (fail_count == 0)
      $display("M10 DPI OUTPUT TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M10 DPI OUTPUT TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
