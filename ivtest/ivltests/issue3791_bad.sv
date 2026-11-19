module issue3791_bad_child(output wire [7:0] q[1:0]);
  assign q[1] = 8'h12;
  assign q[0] = 8'h34;
endmodule

module issue3791_bad_scalar(output wire [7:0] q);
  assign q = 8'h56;
endmodule

module issue3791_bad;
  logic [7:0] overlap[1:0][1:0];
  issue3791_bad_child a[0:1](overlap);
  issue3791_bad_child b(overlap[0]);

  logic [7:0] shared[1:0];
  issue3791_bad_child c[0:1](shared);

  logic [7:0] packed_broadcast[1:0];
  issue3791_bad_scalar d[0:1](packed_broadcast[1]);

  logic [7:0] late_proc[1:0][1:0];
  issue3791_bad_child e[0:1](late_proc);
  initial late_proc[0][0] = 8'hff;

  logic [7:0] initialized[1:0][1:0] = '{'{8'h1, 8'h2}, '{8'h3, 8'h4}};
  issue3791_bad_child f[0:1](initialized);

  logic [7:0] early_assign[1:0][1:0];
  assign early_assign[1][0] = 8'h77;
  issue3791_bad_child g[0:1](early_assign);

  logic [7:0] late_assign[1:0][1:0];
  issue3791_bad_child h[0:1](late_assign);
  assign late_assign[0][1] = 8'h88;
endmodule
