module p07_10_queue;
  int q[$]; int r[$]; int b[$:3]; int v; logic [3:0] xi = 'x;
  initial begin
    q = '{10, 20, 30, 40};
    r = q[2:1];  $display("S1 %0d", r.size());                   // a>b -> {}
    r = q[1:1];  $display("S2 %0d %0d", r.size(), r[0]);         // {q[1]}
    r = q[5:5];  $display("S3 %0d", r.size());                   // n outside the queue -> {}
    r = q[-1:1]; $display("S4 %0d %0d", r.size(), r[0]);         // == q[0:1]
    r = q[2:9];  $display("S5 %0d %0d", r.size(), r[$]);         // == q[2:$]
    r = q[xi:1]; $display("S6 %0d", r.size());                   // X bound -> {}
    v = q[7];    $display("R1 %0d", v);                          // invalid read -> 0
    q[q.size()] = 50; $display("W1 %0d %0d", q.size(), q[$]);         // append legal
    q[9] = 99;   $display("W2 %0d", q.size());                   // invalid write ignored
    q.insert(1, 15); $display("I1 %0d %0d %0d", q.size(), q[1], q[2]);
    q.insert(9, 77); q.insert(-1, 77); $display("I2 %0d", q.size());   // no effect
    q.insert(q.size(), 60); $display("I3 %0d", q[$]);            // index == size: append
    q.delete(0); $display("D1 %0d %0d", q.size(), q[0]);
    q.delete(42); $display("D2 %0d", q.size());                  // no effect
    v = q.pop_front(); $display("P1 %0d %0d", v, q.size());
    v = q.pop_back();  $display("P2 %0d %0d", v, q.size());
    q.push_front(1); q.push_back(2); $display("P3 %0d %0d %0d", q[0], q[$], q.size());
    q.delete(); v = q.pop_front(); $display("P4 %0d %0d", q.size(), v);  // empty pop -> default
    b = '{1, 2, 3, 4}; b.push_back(5); b[b.size()] = 6;
    $display("B1 %0d %0d", b.size(), b[$]);                     // bounded: max 4 elements
    r = '{3, 1}; q = {r, 7, r}; $display("C1 %0d %0d %0d", q.size(), q[2], q[4]);
  end
endmodule
