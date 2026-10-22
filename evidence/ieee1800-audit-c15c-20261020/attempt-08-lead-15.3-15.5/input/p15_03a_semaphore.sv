module p15s;
 int pass=0, fail=0;
 task automatic ck(input string id, input bit c);
  if (c) pass++; else begin fail++; $display("FAIL %s", id); end
 endtask
 semaphore s = new(2), z = new(0), p = new(0), sm = new(0), s2 = new(0);
 int ok1, ok2, no3, p1, p2, p3, p4, ta=-1, tb=-1, tc=-1;
 initial begin
  ok1=s.try_get(); ok2=s.try_get(); no3=s.try_get();
  ck("try_get", ok1>0 && ok2>0 && no3==0);
  ck("zero_keys", z.try_get()==0);
  p.put(3); p1=p.try_get(); p2=p.try_get(); p3=p.try_get(); p4=p.try_get();
  ck("put_adds_keys", p1>0 && p2>0 && p3>0 && p4==0);
  #30;
  ck("blocking_fifo", ta==10 && tb==20);
  ck("multi_key", tc==12);
  $display("RESULT pass=%0d fail=%0d", pass, fail); $finish;
 end
 initial begin #1 sm.get(); ta=$time; end
 initial begin #2 sm.get(); tb=$time; end
 initial begin #10 sm.put(); #10 sm.put(); end
 initial begin #3 s2.get(2); tc=$time; end
 initial #12 s2.put(2);
endmodule
