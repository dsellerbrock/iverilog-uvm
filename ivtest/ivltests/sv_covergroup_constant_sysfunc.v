// IEEE 1800-2017/2023 19.5 and 11.2.1: constant system functions remain
// legal in covergroup expressions.
module top;
  bit [3:0] value = 3;
  covergroup cg;
    cp: coverpoint value { bins valid = {$clog2(8)}; }
  endgroup
  cg cov = new;
  initial begin
    cov.sample();
    $display("CONSTANT_SYSTEM_FUNCTION=%0.1f", cov.get_inst_coverage());
  end
endmodule
