// IEEE 1800-2017/2023 16.12.22: an empty-only overlapped antecedent
// is illegal. The default and one sibling are valid; only N=0 is rejected.
module empty_overlap_checker #(parameter N=1)(input clk,a);
 assert property (@(posedge clk) a[*N] |-> 1'b1);
endmodule
module sv_assert_symbolic_empty_overlap_fail;
 reg clk=0,a=0;
 empty_overlap_checker valid(clk,a);
 empty_overlap_checker #(.N(0)) invalid(clk,a);
endmodule
