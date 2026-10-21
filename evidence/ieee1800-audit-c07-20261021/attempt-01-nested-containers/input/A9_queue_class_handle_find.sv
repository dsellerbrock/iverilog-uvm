class C;
  int v;
endclass
module tb;
  C q[$];
  C hq[$];
  C c;
  initial begin
    c = new; c.v = 3; q.push_back(c);
    c = new; c.v = 1; q.push_back(c);
    c = new; c.v = 2; q.push_back(c);
    hq = q.find_first with (item == q[2]);
    $display("A9 %0d", hq[0] == q[2]);
  end
endmodule
