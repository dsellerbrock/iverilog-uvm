package issue941_checker_package;
  logic package_sample = 1;
  checker package_checker(logic clk, logic s);
    a: assert property (@(posedge clk) s && package_sample);
  endchecker
endpackage

module issue941_checker_scope;
  logic clk = 0;
  logic reset_n = 1;
  logic condition = 1;
  int module_failures = 0;
  int generate_failures = 0;
  int orphan_failures = 0;

  import issue941_checker_package::*;

  default clocking cb @(posedge clk); endclocking
  default disable iff (!reset_n);

  checker module_checker(logic s);
    a: assert property (s) else module_failures++;
  endchecker
  module_checker module_instance(condition);
  package_checker package_instance(clk, 1'b1);

  checker orphan_checker;
    a: assert property (@(posedge clk) 1'b0) else orphan_failures++;
  endchecker

  if (1) begin : generated_scope
    checker generate_checker(logic s);
      default disable iff (!reset_n);
      a: assert property (@(posedge clk) s) else generate_failures++;
    endchecker
    generate_checker generate_instance(condition);
  end

  initial begin
    #1 clk = 1;
    #1 clk = 0;
    #1 reset_n = 0; condition = 0; clk = 1;
    #1 clk = 0;
    #1 reset_n = 1; clk = 1;
    #1 clk = 0;
    #1 if (module_failures != 1 || generate_failures != 1
          || orphan_failures != 0)
      $fatal(1, "unexpected checker results module=%0d generate=%0d orphan=%0d",
             module_failures, generate_failures, orphan_failures);
    $display("PASSED");
    $finish;
  end
endmodule
