// Regression: two parse gaps surfaced by OpenTitan spi_host (both parse-and-
// ignore -- functional coverage and bind directives are not modeled here):
//   1. Transition bins whose value-sets are [lo:hi] ranges, e.g.
//        bins Any2Any[] = ([Standard:Quad] => [Standard:Quad]);
//      (spi_host_env_cov.sv). transition value-sets previously accepted only
//      single expressions, not ranges.
//   2. A `bind` directive targeting a HIERARCHICAL instance path, e.g.
//        bind dut.u_core fsm_if bound_if();
//      (spi_host tb.sv). The bind target previously had to be a single
//      identifier.
typedef enum bit [2:0] { Standard, Dual, Quad, RsvdSpd } spd_e;

interface fsm_if(); logic x; endinterface
module sub; logic y; endmodule
module dut; sub u_core(); endmodule

module top;
  dut d();
  // bind to a hierarchical target path
  bind d.u_core fsm_if bound_if();

  class c;
    spd_e m;
    covergroup cg;
      cp: coverpoint m {
        bins Any2Any[] = ([Standard:Quad] => [Standard:Quad]);  // range transition
      }
    endgroup
    function new(); cg = new(); endfunction
    function int sentinel(); return 5; endfunction
  endclass

  initial begin
    c o = new();
    if (o.sentinel() == 5) $display("PASS");
    else $display("FAIL");
  end
endmodule
