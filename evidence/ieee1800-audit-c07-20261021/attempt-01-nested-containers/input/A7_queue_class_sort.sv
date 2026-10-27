class C;
  int v;
endclass
module tb;
  C q[$];
  C c;
  initial begin
    c = new; c.v = 3; q.push_back(c);
    c = new; c.v = 1; q.push_back(c);
    c = new; c.v = 2; q.push_back(c);
    q.sort with (item.v);
    $display("A7 %0d %0d %0d", q[0].v, q[1].v, q[2].v);
  end
endmodule
