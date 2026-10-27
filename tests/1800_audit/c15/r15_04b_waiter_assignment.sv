module p15_order;
 mailbox #(int) q = new;
 int w1 = -1, w2 = -1, w3 = -1;
 int ord[$];
 initial begin #1 q.get(w1); ord.push_back(1); end
 initial begin #2 q.get(w2); ord.push_back(2); end
 initial begin #3 q.get(w3); ord.push_back(3); end
 initial begin #10 q.put(100); q.put(200); q.put(300); end
 initial begin
  #20;
  $display("ASSIGN w1=%0d w2=%0d w3=%0d", w1, w2, w3);
  $display("RESUME count=%0d order=%0d,%0d,%0d", ord.size(), ord[0], ord[1], ord[2]);
  if (w1==100 && w2==200 && w3==300)
   $display("RESULT pass=1 fail=0");
  else
   $display("RESULT pass=0 fail=1");
  $finish;
 end
endmodule
