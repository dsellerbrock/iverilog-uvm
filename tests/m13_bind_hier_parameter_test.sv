// IEEE 1800-2017 23.11: a bound instance is elaborated in the target
// scope. Its parameter overrides may use a parameter of a target child.
module m13_bind_hier_parameter_child #(
  parameter bit Enabled = 1'b0
);
endmodule

module m13_bind_hier_parameter_target;
  m13_bind_hier_parameter_child #(.Enabled(1'b1)) u_child();
endmodule

module m13_bind_hier_parameter_probe #(
  parameter bit Enabled = 1'b0
);
  initial begin
    if (Enabled !== 1'b1) begin
      $display("M13 BIND HIER PARAMETER TEST: FAIL Enabled=%b", Enabled);
      $finish(1);
    end
    $display("M13 BIND HIER PARAMETER TEST: PASS");
  end
endmodule

module m13_bind_hier_parameter_apply;
  bind m13_bind_hier_parameter_target
    m13_bind_hier_parameter_probe #(.Enabled(u_child.Enabled)) probe();
endmodule

module m13_bind_hier_parameter_test;
  m13_bind_hier_parameter_target dut();
endmodule
