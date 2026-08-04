// IEEE 1800-2017 23.11: parameter overrides on a bound instance are
// elaborated in the scope of the bind target. This includes string
// parameters, a shape used by OpenTitan security-countermeasure probes.
module m13_bind_param_target #(
  parameter int WIDTH = 4,
  parameter string FORCE_NAME = "state_q"
) ();
endmodule

module m13_bind_param_probe #(
  parameter int WIDTH = 0,
  parameter string FORCE_NAME = ""
) ();
endmodule

bind m13_bind_param_target m13_bind_param_probe #(
  .WIDTH(WIDTH),
  .FORCE_NAME(FORCE_NAME)
) u_probe ();

module m13_bind_target_parameter_test;
  m13_bind_param_target #(
    .WIDTH(11),
    .FORCE_NAME("aes_cipher_ctrl_cs")
  ) dut ();

  initial begin
    #1;
    if (dut.u_probe.WIDTH != 11 ||
        dut.u_probe.FORCE_NAME != "aes_cipher_ctrl_cs") begin
      $display("FAIL: bound instance did not inherit target parameters");
      $finish_and_return(1);
    end
    $display("PASS: bound instance inherited numeric and string target parameters");
    $finish;
  end
endmodule
