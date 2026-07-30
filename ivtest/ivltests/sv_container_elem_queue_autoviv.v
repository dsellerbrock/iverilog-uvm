// Mutating a fresh queue element of a positional container:
// dq[i].push_back(v) for darray-of-queue and queue-of-queue, directly
// and through a class property. Per IEEE 1800-2017 7.5/7.9 a fresh
// element is an empty QUEUE (a value), not null — pre-fix the element
// load returned nil and the runtime dropped every mutation with only
// a "queue operation on a null queue value was skipped" warning
// (recovery D14). Class-handle elements must NOT be vivified — a
// fresh handle element stays null.
module main;
  int dq[][$];
  int qq[$][$];
  string sq[][$];

  class C;
    int qq[$][$];
  endclass
  C c;

  int fails = 0;

  initial begin
    // darray of queues
    dq = new[2];
    dq[0].push_back(5);
    dq[0].push_back(6);
    dq[1].push_back(7);
    if (dq[0].size() !== 2 || dq[0][0] !== 5 || dq[0][1] !== 6) begin
      fails++; $display("FAILED: dq[0] %0d/%0d/%0d", dq[0].size(), dq[0][0], dq[0][1]);
    end
    if (dq[1].size() !== 1 || dq[1][0] !== 7) begin
      fails++; $display("FAILED: dq[1] %0d/%0d", dq[1].size(), dq[1][0]);
    end

    // queue of queues: grow the outer, then mutate elements in place
    qq.push_back({});
    qq.push_back({});
    qq[0].push_back(5);
    qq[0].push_back(6);
    qq[1].push_back(7);
    if (qq[0].size() !== 2 || qq[0][0] !== 5 || qq[1][0] !== 7) begin
      fails++; $display("FAILED: qq %0d/%0d/%0d", qq[0].size(), qq[0][0], qq[1][0]);
    end

    // string-element inner queues
    sq = new[1];
    sq[0].push_back("hi");
    if (sq[0].size() !== 1 || sq[0][0] != "hi") begin
      fails++; $display("FAILED: sq '%s'", sq[0][0]);
    end

    // through a class property
    c = new;
    c.qq.push_back({});
    c.qq[0].push_back(11);
    c.qq[0].push_back(12);
    if (c.qq[0].size() !== 2 || c.qq[0][0] !== 11 || c.qq[0][1] !== 12) begin
      fails++; $display("FAILED: c.qq %0d/%0d/%0d", c.qq[0].size(), c.qq[0][0], c.qq[0][1]);
    end

    // insert/delete through the same autoviv receiver
    begin
      int dq2[][$];
      dq2 = new[1];
      dq2[0].push_back(1);
      dq2[0].insert(0, 0);
      if (dq2[0].size() !== 2 || dq2[0][0] !== 0 || dq2[0][1] !== 1) begin
        fails++; $display("FAILED: insert %0d/%0d/%0d", dq2[0].size(), dq2[0][0], dq2[0][1]);
      end
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
