module p15e;
 int pass=0, fail=0;
 task automatic ck(input string id, input bit c);
  if (c) pass++; else begin fail++; $display("FAIL %s", id); end
 endtask
 event e1, e2, a, nb, done, blast, wa, wb, wc, xa, xb;
 int n1=0, n2=0, late=0, tr=0, trg_same=-1, trg_later=-1, blast_ok=0;
 int nbt=-1, nbo=-1, wo_ok=0, wo_fail=0;
 task trigger(event ev); -> ev; endtask
 initial begin @e1; n1++; end
 initial begin @e1; n2++; end
 initial #5 -> e1;
 initial #1 -> e2;
 initial begin #2 @e2; late=1; end
 initial #10 -> a;
 initial begin #10 wait(a.triggered); trg_same=$time; end
 initial #11 trg_later=a.triggered;
 initial begin #20 fork -> blast; begin wait(blast.triggered); blast_ok=1; end join end
 initial begin @done; tr=1; end
 initial #30 trigger(done);
 initial begin #40 @nb; nbt=$time; end
 initial begin #40 ->> nb; nbo=nb.triggered; end
 initial begin wait_order(wa, wb, wc) wo_ok=1; else wo_ok=-1; end
 initial begin #50 -> wa; #1 -> wb; #1 -> wc; end
 initial begin wait_order(xa, xb) wo_fail=-1; else wo_fail=1; end
 initial begin #60 -> xb; #1 -> xa; end
 initial begin
  #100;
  ck("all_waiters", n1==1 && n2==1);
  ck("trigger_before_wait", late==0);
  ck("triggered_same_time", trg_same==10);
  ck("triggered_expires", trg_later==0);
  ck("fork_blast", blast_ok==1);
  ck("event_argument", tr==1);
  ck("nonblocking", nbo==0 && nbt==40);
  ck("wait_order_pass", wo_ok==1);
  ck("wait_order_fail", wo_fail==1);
  $display("RESULT pass=%0d fail=%0d", pass, fail); $finish;
 end
endmodule
