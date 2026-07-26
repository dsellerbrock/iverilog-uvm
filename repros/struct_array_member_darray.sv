module top;
  typedef struct { int da[]; int tag; } s_t;
  typedef struct { int q[$]; } q_t;
  s_t s;
  q_t qq;
  int plain_da[];
  initial begin
    s.da = new[3]; s.da[0] = 10; s.da[1] = 20; s.da[2] = 30;
    s.tag = 5;
    plain_da = new[3]; plain_da[1] = 20;
    qq.q.push_back(7); qq.q.push_back(8);
    $display("size=%0d (want 3)", s.da.size());
    $display("elems=%0d %0d %0d (want 10 20 30)", s.da[0], s.da[1], s.da[2]);
    $display("tag=%0d (want 5)", s.tag);
    $display("plain darray[1]=%0d (want 20)", plain_da[1]);
    $display("queue member size=%0d (want 2) elem=%0d (want 8)", qq.q.size(), qq.q[1]);
    $finish(0);
  end
endmodule
