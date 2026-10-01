// Coverpoint expressions resolve in the scope that declares the covergroup
// (IEEE 1800-2017/2023 19.3). A covergroup in an interface sampled from
// outside (u.cg.sample(v)) looked the interface's function up in the
// caller's scope, failed, and sampled a constant (OpenTitan entropy_src
// coverage interface).
interface cov_if (input logic clk);
  function automatic int unsigned bucket(int v);
    return v / 10;
  endfunction
  covergroup b_cg with function sample(int v);
    option.per_instance = 1;
    cp : coverpoint bucket(v) { bins b[] = {[0:3]}; }
  endgroup
  b_cg cg = new;
endinterface
module test;
  logic clk = 0;
  cov_if u (clk);
  initial begin
    u.cg.sample(5);    // bucket 0
    u.cg.sample(25);   // bucket 2
    if (u.cg.get_inst_coverage() == 50.0) $display("PASSED");
    else $display("FAILED %f", u.cg.get_inst_coverage());
  end
endmodule
