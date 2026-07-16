// M13: pin specify-block module path delays (IEEE 1800-2017 clause 31),
// which the audit found working. A rising input propagates to the output
// after the specified rise delay; a falling input after the fall delay.
// Compiled with -gspecify (see .github/uvm_test.sh IVFLAGS).
`timescale 1ns/1ps

module m13s_buf(input a, output y);
  assign y = a;
  specify
    (a => y) = (4, 7);   // rise delay 4ns, fall delay 7ns
  endspecify
endmodule

module m13_specify_paths_test_top;
  reg a = 0;
  wire y;
  m13s_buf u(.a(a), .y(y));

  time t_rise_in, t_rise_out, t_fall_in, t_fall_out;
  int errors = 0;

  initial begin
    #10 a = 1; t_rise_in = $time;
    @(posedge y); t_rise_out = $time;
    if ((t_rise_out - t_rise_in) != 4) begin
      $display("FAIL: rise delay %0t (expected 4)", t_rise_out - t_rise_in);
      errors++;
    end
    #10 a = 0; t_fall_in = $time;
    @(negedge y); t_fall_out = $time;
    if ((t_fall_out - t_fall_in) != 7) begin
      $display("FAIL: fall delay %0t (expected 7)", t_fall_out - t_fall_in);
      errors++;
    end
    if (errors == 0) $display("PASS: m13 specify path delays");
    else $display("FAIL: m13 specify path delays (%0d errors)", errors);
    $finish(0);
  end
endmodule
