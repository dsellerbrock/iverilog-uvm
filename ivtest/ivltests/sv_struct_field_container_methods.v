// Void/statement-style container methods on struct fields:
// a.q.push_back / insert / pop_front / delete(idx) / delete(),
// a.da.delete(), a.aa.delete(key) / delete(). Pre-fix every one of
// these silently no-opped ("warning: Enable of unknown task ...
// ignored") because the method-call walker only stepped through class
// hops, never struct members — while the value-returning reads beside
// them worked, making the drops easy to miss (recovery SF-1/2/3).
module main;
  typedef struct {
    int q[$];
    int da[];
    int aa[string];
  } S;

  S a;
  int fails = 0;

  initial begin
    // queue round-trip
    a.q.push_back(1);
    a.q.push_back(2);
    a.q.push_back(3);
    if (a.q.size() !== 3) begin fails++; $display("FAILED: push size=%0d", a.q.size()); end
    if (a.q[0] !== 1 || a.q[1] !== 2 || a.q[2] !== 3) begin
      fails++; $display("FAILED: push vals %0d %0d %0d", a.q[0], a.q[1], a.q[2]);
    end
    a.q.insert(1, 99);
    if (a.q.size() !== 4 || a.q[1] !== 99) begin
      fails++; $display("FAILED: insert size=%0d q1=%0d", a.q.size(), a.q[1]);
    end
    void'(a.q.pop_front());
    if (a.q.size() !== 3 || a.q[0] !== 99) begin
      fails++; $display("FAILED: pop_front size=%0d q0=%0d", a.q.size(), a.q[0]);
    end
    a.q.delete(0);
    if (a.q.size() !== 2 || a.q[0] !== 2) begin
      fails++; $display("FAILED: delete(0) size=%0d q0=%0d", a.q.size(), a.q[0]);
    end
    a.q.delete();
    if (a.q.size() !== 0) begin fails++; $display("FAILED: delete() size=%0d", a.q.size()); end

    // darray delete
    a.da = new[3];
    a.da[0] = 10; a.da[1] = 11; a.da[2] = 12;
    if (a.da.size() !== 3) begin fails++; $display("FAILED: da size=%0d", a.da.size()); end
    a.da.delete();
    if (a.da.size() !== 0) begin fails++; $display("FAILED: da delete size=%0d", a.da.size()); end

    // assoc keyed and whole delete
    a.aa["x"] = 100;
    a.aa["y"] = 200;
    a.aa.delete("x");
    if (a.aa.size() !== 1 || a.aa.exists("x")) begin
      fails++; $display("FAILED: aa delete(key) size=%0d", a.aa.size());
    end
    a.aa.delete();
    if (a.aa.size() !== 0) begin fails++; $display("FAILED: aa delete() size=%0d", a.aa.size()); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
