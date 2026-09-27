// A block may declare an explicitly automatic or static variable of a
// package-scoped class type that is not otherwise visible (IEEE
// 1800-2017/2023 6.21), as OpenTitan's rstmgr_cnsty_chk tb.sv does with
// `automatic dv_utils_pkg::dv_report_server dv_report_server = new();'.
package p;
  class srv;
    int v = 5;
  endclass
  class box #(int N = 1);
    int n = N;
  endclass
endpackage

module test;
  initial begin
    automatic p::srv srv = new();
    static p::srv s2;
    automatic p::box #(3) b = new();
    s2 = srv;
    if (srv.v === 5 && s2.v === 5 && b.n === 3)
      $display("PASSED");
    else
      $display("FAILED: %0d %0d %0d", srv.v, s2.v, b.n);
  end
endmodule
