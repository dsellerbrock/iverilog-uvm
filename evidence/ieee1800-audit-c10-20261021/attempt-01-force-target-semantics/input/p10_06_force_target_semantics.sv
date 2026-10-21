// IEEE 1800-2017/2023 §10.6.2 force/release target and variable semantics.
module p10_06_force_target_semantics;
  logic [3:0] variable_value;
  wire [3:0] net_value;
  int checks = 0;
  int failures = 0;

  assign net_value = 4'b0101;

  task automatic check(input string label, input logic [3:0] actual,
                       input logic [3:0] expected);
    if (actual !== expected) begin
      failures++;
      $display("FAIL %s got=%b expected=%b", label, actual, expected);
    end else checks++;
  endtask

  initial begin
    force net_value[1] = 1'b1;
    #1 check("force net bit-select", net_value, 4'b0111);
    release net_value[1];
    #1 check("release net bit-select", net_value, 4'b0101);

    force net_value[3:2] = 2'b11;
    #1 check("force net part-select", net_value, 4'b1101);
    release net_value[3:2];
    #1 check("release net part-select", net_value, 4'b0101);

    variable_value = 4'h3;
    force variable_value = 4'hA;
    variable_value = 4'h5;
    #1 check("procedural assignment while forced", variable_value, 4'hA);
    release variable_value;
    #1 check("released variable retains value", variable_value, 4'hA);
    variable_value = 4'h6;
    #1 check("next procedural assignment", variable_value, 4'h6);

    $display("RESULT checks=%0d failures=%0d", checks, failures);
    if (failures != 0) $fatal(1, "force/release target semantics failed");
    $finish;
  end
endmodule
