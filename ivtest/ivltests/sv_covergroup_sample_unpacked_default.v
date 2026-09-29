// IEEE 1800-2017/2023 13.5.3, 19.3, 19.5: an omitted fixed-array
// sample argument reads its package default afresh at each call. The
// formal [1:0] maps left-to-left from the package actual [0:1].
package default_flags_pkg;
  typedef struct packed { logic Z, L, M, C; } flags_t;
  flags_t module_flags[0:1];
endpackage

module top;
  import default_flags_pkg::*;
  covergroup cg with function sample(
      default_flags_pkg::flags_t flags[1:0] =
      default_flags_pkg::module_flags);
    option.per_instance = 1;
    cp: coverpoint flags[0].C {
      bins zero = {1'b0};
      bins one = {1'b1};
    }
  endgroup
  cg cov;
  initial begin
    module_flags[0] = 4'b0101;
    module_flags[1] = 4'b1010;
    cov = new;
    cov.sample();
    if (cov.get_inst_coverage() != 50.0)
      $fatal(1, "first omitted array default missed actual index 1");
    module_flags[1] = 4'b1011;
    cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "omitted array default was not evaluated again");
    $display("PASSED");
  end
endmodule
