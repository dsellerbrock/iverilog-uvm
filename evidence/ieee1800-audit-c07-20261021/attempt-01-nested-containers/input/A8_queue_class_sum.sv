class C;
  int v;
endclass
module tb;
  C q[$];
  C c;
  int s;
  initial begin
    c = new; c.v = 3; q.push_back(c);
    c = new; c.v = 1; q.push_back(c);
    c = new; c.v = 2; q.push_back(c);
    s = q.sum with (int'(item.v));
    $display("A8 %0d", s);
  end
endmodule
