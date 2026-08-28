// IEEE 1800-2017/2023 23.11 / Syntax 23-9: a checker instantiation is
// permitted as the bound instantiation when the selected target is an
// interface. An assertion action updates a package counter so the checker's
// execution is observable without an illegal hierarchical checker-member
// reference.
package sv_bind_interface_checker_counts;
  int samples;
endpackage

interface sv_bind_interface_checker_intf;
  logic clk = 1'b0;
  logic sample_ok = 1'b0;
endinterface

checker sv_bind_interface_checker_probe(input logic clk, sample_ok);
  import sv_bind_interface_checker_counts::*;

  a_sample: assert property (@(posedge clk) sample_ok)
    else samples++;
endchecker

bind sv_bind_interface_checker_intf sv_bind_interface_checker_probe
  bound_checker(.clk(clk), .sample_ok(sample_ok));

module sv_bind_interface_checker;
  sv_bind_interface_checker_intf target();

  always #1 target.clk = ~target.clk;

  initial begin
    #6;
    if (sv_bind_interface_checker_counts::samples == 3)
      $display("PASSED");
    else
      $display("FAILED: samples=%0d",
               sv_bind_interface_checker_counts::samples);
    $finish(0);
  end
endmodule
