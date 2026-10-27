class C;
  int v;
endclass
module tb;
  C q[$];
  C r[$];
  int ix[$];
  C c;
  initial begin
    c = new; c.v = 3; q.push_back(c);
    c = new; c.v = 1; q.push_back(c);
    c = new; c.v = 2; q.push_back(c);
    r = q.find with (item.v > 1);
    ix = q.find_first_index with (item.v == 1);
    $display("A6 %0d %0d", r.size(), ix[0]);
  end
endmodule
