// IEEE 1800-2017/2023 §11.4.13: nonintegral membership uses == comparisons.
module p11_13_nonintegral_inside;
  string text;
  real value;
  int checks = 0;
  int failures = 0;

  task automatic check(input string label, input logic actual,
                       input logic expected);
    if (actual !== expected) begin
      failures++;
      $display("FAIL %s got=%b expected=%b", label, actual, expected);
    end else checks++;
  endtask

  initial begin
    text = "middle";
    check("string item equality", text inside {"other", "middle"}, 1'b1);
    check("string range", text inside {["alpha":"zulu"]}, 1'b1);
    check("string range miss", text inside {["x":"z"]}, 1'b0);

    value = 1.5;
    check("real item equality", value inside {1.0, 1.5}, 1'b1);

    $display("RESULT checks=%0d failures=%0d", checks, failures);
    if (failures != 0) $fatal(1, "nonintegral inside probe failed");
    $finish;
  end
endmodule
