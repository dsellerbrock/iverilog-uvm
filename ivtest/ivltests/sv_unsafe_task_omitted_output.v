// An omitted output argument with no default is illegal (IEEE 1800-2017/2023
// 13.5.3). Commercial tools discard the result (OpenTitan entropy_src:
// `csr_rd(.ptr(reg))'), so Icarus does too, only under -gcommercial-unsafe;
// sv_task_omitted_output_fail keeps strict mode.
class util;
  static int reads;
  static task automatic csr_rd(input int ptr, output int value, input bit check = 1);
    reads++;
    value = ptr * 2;
  endtask
endclass
module test;
  int v;
  initial begin
    util::csr_rd(.ptr(3));          // output omitted: result discarded
    util::csr_rd(.ptr(4), .value(v));
    if (util::reads == 2 && v == 8) $display("PASSED");
    else $display("FAILED %0d %0d", util::reads, v);
  end
endmodule
