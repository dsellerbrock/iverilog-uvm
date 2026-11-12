module tb;
  int m[2][3] = '{'{1, 2, 3}, '{4, 5, 6}};
  int q[$];

  initial begin
    q = {m};
    $display("%p", q);
  end
endmodule
