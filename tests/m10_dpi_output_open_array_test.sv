// M10-6: an OUTPUT open-array formal of a DPI import arrived EMPTY, and
// the empty formal was then copied back over the actual.
//
// For an ordinary SystemVerilog subroutine an output argument is
// write-only: 13.5.2 copies it out at return and the formal starts
// uninitialized, so there is nothing to copy in. A DPI open array is not
// that. IEEE 1800-2017 35.5.6.1 and H.10.2 say the ACTUAL argument
// determines the open array's shape, and the C side reads that shape
// back through svSize/svLow/svHigh before it writes a single element.
// Only the element VALUES are outputs.
//
// The copy-in was skipped on direction alone, so
//
//     import "DPI-C" function void c_fill(output int a[]);
//     dyn = new[4];  c_fill(dyn);
//
// handed C an unallocated formal: svSize returned 0 and svLow/svHigh
// returned the degenerate pair -1/0 -- which makes the natural
// `for (i = svLow; i <= svHigh; i++)' loop run TWICE, out of bounds --
// svGetArrElemPtr1 returned NULL for every index, and on return the
// empty formal was copied back over the actual, leaving dyn.size() == 0.
// The caller's array was destroyed. No diagnostic, exit 0.
//
// The `input' direction was correct throughout, which is what kept this
// hidden; it is the control below.
//
// The C side returns a bitmask of shape errors so a wrong size or bound
// fails the test rather than needing to be spotted in a log.

module m10_dpi_output_open_array_test;

  // VOID imports called as STATEMENTS: that is the shape that was
  // broken. A value-returning import used in an expression takes the
  // function path, which always copied every argument in.
  import "DPI-C" function void c_out_fill  (output int  a[], input int want_size,
                                            output int status);
  import "DPI-C" function void c_inout_bump(inout  int  a[], input int want_size,
                                            output int status);
  import "DPI-C" function void c_out_real  (output real r[], input int want_size,
                                            output int status);

  int  dyn[];
  int  io[];
  real rd[];

  int  bad;
  int  fails = 0;

  initial begin

    // ---- output: the shape must arrive, the values must come back ----
    dyn = new[4];
    c_out_fill(dyn, 4, bad);
    if (bad != 0) begin
      fails++;
      $display("FAILED -- output open array shape wrong in C: mask=%0d (1=size 2=low 4=high 8=null elem)", bad);
    end
    if (dyn.size() !== 4) begin
      fails++;
      $display("FAILED -- the actual was resized by the call: size=%0d want 4",
               dyn.size());
    end else begin
      for (int i = 0; i < 4; i++)
        if (dyn[i] !== i*7) begin
          fails++;
          $display("FAILED -- output value [%0d]=%0d want %0d", i, dyn[i], i*7);
        end
    end

    // ---- inout: reads the caller's values AND writes back ----
    io = new[3];
    for (int i = 0; i < 3; i++) io[i] = i + 1;
    c_inout_bump(io, 3, bad);
    if (bad != 0) begin
      fails++;
      $display("FAILED -- inout open array shape wrong in C: mask=%0d", bad);
    end
    if (io.size() !== 3) begin
      fails++;
      $display("FAILED -- inout resized the actual: size=%0d want 3", io.size());
    end else begin
      for (int i = 0; i < 3; i++)
        if (io[i] !== (i + 1 + 1000)) begin
          fails++;
          $display("FAILED -- inout value [%0d]=%0d want %0d",
                   i, io[i], i + 1 + 1000);
        end
    end

    // ---- the same for a real element type ----
    rd = new[3];
    c_out_real(rd, 3, bad);
    if (bad != 0) begin
      fails++;
      $display("FAILED -- real output open array shape wrong in C: mask=%0d", bad);
    end
    if (rd.size() !== 3) begin
      fails++;
      $display("FAILED -- real output resized the actual: size=%0d want 3",
               rd.size());
    end else begin
      for (int i = 0; i < 3; i++)
        if (rd[i] != i * 1.5) begin
          fails++;
          $display("FAILED -- real output value [%0d]=%f want %f",
                   i, rd[i], i * 1.5);
        end
    end

    if (fails == 0) $display("TEST PASSED");
    else            $display("TEST FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
