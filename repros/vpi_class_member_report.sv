module top;
  class C;
    int      sc;          // scalar
    int      fa[4];       // fixed unpacked array
    int      dq[$];       // queue
    int      da[];        // dynamic array
    int      aa[string];  // associative
  endclass
  C c;
  initial begin
    c = new();
    c.sc = 1;
    c.fa[0] = 1;
    c.dq.push_back(1); c.dq.push_back(2);
    c.da = new[3];
    c.aa["k"] = 5;
    $probe_members(c);
    $finish(0);
  end
endmodule
