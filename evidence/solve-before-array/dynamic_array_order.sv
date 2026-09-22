class Q; rand bit m; rand bit [7:0] q[]; constraint c { q.size() == 2; solve m before q; foreach (q[i]) m -> q[i] == 5; } endclass
class U; rand bit m; rand bit [7:0] q[]; constraint c { q.size() == 2; foreach (q[i]) m -> q[i] == 5; } endclass
module top; Q q; U u; int a, b; initial begin q = new; u = new; repeat (400) begin void'(q.randomize()); a += q.m; void'(u.randomize()); b += u.m; end $display("dyn ordered m=1 %0d/400, unordered %0d/400", a, b); end endmodule
