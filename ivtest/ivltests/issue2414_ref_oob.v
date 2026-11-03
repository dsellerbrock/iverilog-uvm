module issue2414_ref_oob;
  int q[$];
  int d[];
  logic q4[$];
  logic d4[];

  task automatic rd(ref int r);
    $display("rd %0d", r);
  endtask

  task automatic rd4(ref logic r);
    $display("rd4 %b", r);
  endtask

  initial begin
    q = '{1, 2};
    d = new[2];
    rd(q[5]);
    rd(d[7]);
    $display("direct %0d %0d", q[5], d[7]);
    q4 = '{1};
    d4 = new[1];
    rd4(q4[3]);
    rd4(d4[3]);
    $display("direct4 %b %b", q4[3], d4[3]);
  end
endmodule
