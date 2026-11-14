module top;
  int m[2][2] = '{'{1, 2}, '{3, 4}};
  int d[1:0][0:1][1:0] = '{'{'{1, 2}, '{3, 4}},
                              '{'{5, 6}, '{7, 8}}};
  logic [3:0] a[2][3] = '{'{4'h1, 4'h2, 4'h3},
                            '{4'h4, 4'hx, 4'hf}};
  initial begin
    $display("%p", m);
    $display("%p", d);
    $display("%p", a);
  end
endmodule
