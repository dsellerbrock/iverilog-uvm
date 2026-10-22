module p15m;
 int pass=0, fail=0;
 task automatic ck(input string id, input bit c);
  if (c) pass++; else begin fail++; $display("FAIL %s", id); end
 endtask
 class C;
  int v;
  function new(int x); v=x; endfunction
 endclass
 typedef mailbox #(string) s_mbox;
 mailbox mb = new, bm = new(2), pk = new, wq = new, ub = new, gm = new;
 s_mbox sm = new;
 int i, j, r, pa, pb, w1, w2, w3, put_t = -1, get_t = -1, got_x = 0, j2;
 string s;
 C c1, c2;
 int ord[$];
 initial begin
  ck("num0", mb.num()==0);
  mb.put(1); mb.put(2); mb.put(3); ck("num3", mb.num()==3);
  mb.get(i); mb.get(j); ck("fifo", i==1 && j==2 && mb.num()==1);
  mb.peek(i); ck("peek", i==3 && mb.num()==1);
  r = mb.try_peek(i); ck("try_peek", r>0 && i==3 && mb.num()==1);
  r = mb.try_get(i); ck("try_get", r>0 && i==3 && mb.num()==0);
  ck("empty_try", mb.try_get(i)==0 && mb.try_peek(i)==0);
  ck("try_put", bm.try_put(10)>0 && bm.try_put(11)>0 && bm.try_put(12)==0 && bm.num()==2);
  c1 = new(7); mb.put(c1); mb.get(c2); ck("handle", c2==c1 && c2.v==7);
  mb.put("str"); mb.get(s); ck("string_msg", s=="str");
  sm.put("hello"); sm.get(s); ck("param", s=="hello");
  for (int k=0;k<100;k++) ub.put(k); ck("unbounded", ub.num()==100);
  #20 ck("bounded_put", put_t==5 && bm.num()==2);
  ck("blocking_get", get_t==3 && got_x==55);
  ck("waiters_fifo", ord.size()==3 && ord[0]==1 && ord[1]==2 && ord[2]==3 && w1==100 && w2==200 && w3==300);
  ck("peek_unblocks_both", pa==77 && pb==77 && pk.num()==1);
  $display("RESULT pass=%0d fail=%0d", pass, fail); $finish;
 end
 initial begin #1 bm.put(99); put_t = $time; end
 initial #5 bm.get(j2);
 initial begin gm.get(got_x); get_t = $time; end
 initial #3 gm.put(55);
 initial begin #1 wq.get(w1); ord.push_back(1); end
 initial begin #2 wq.get(w2); ord.push_back(2); end
 initial begin #3 wq.get(w3); ord.push_back(3); end
 initial begin #10 wq.put(100); wq.put(200); wq.put(300); end
 initial pk.peek(pa);
 initial pk.peek(pb);
 initial #1 pk.put(77);
endmodule
