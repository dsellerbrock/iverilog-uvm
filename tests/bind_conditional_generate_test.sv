// IEEE 1800-2017 27.2 / 23.11: a bind directive is a generate item.
// A bind in an unselected conditional-generate arm must not be applied.

module bind_conditional_generate_dut;
  logic present = 1'b1;
endmodule

module bind_conditional_generate_good(input logic value);
  int good_count = 0;
  initial if (value) good_count++;
endmodule

module bind_conditional_generate_bad(input logic value);
endmodule

module bind_conditional_generate_container;
  if (0) begin : disabled_bind
    // `absent' deliberately does not exist in the target. If this bind is
    // incorrectly applied, elaboration fails before the runtime check.
    bind bind_conditional_generate_dut bind_conditional_generate_bad bad(.value(absent));
  end

  if (1) begin : enabled_bind
    bind bind_conditional_generate_dut bind_conditional_generate_good good(.value(present));
  end
endmodule

module bind_conditional_generate_test;
  bind_conditional_generate_dut dut();
  bind_conditional_generate_container container();

  initial begin
    #1;
    if (dut.good.good_count == 1)
      $display("PASS: conditional-generate bind selection");
    else
      $display("FAIL: conditional-generate bind count=%0d expected=1",
               dut.good.good_count);
    $finish;
  end
endmodule
