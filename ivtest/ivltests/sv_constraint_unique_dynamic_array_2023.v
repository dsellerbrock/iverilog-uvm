// `unique {q}' over a rand dynamic array or queue, and a foreach nested over the
// same array (IEEE 1800-2017/2023 18.5.5, 18.5.8). The unique constraint was
// dropped without a diagnostic -- a quarter of the draws held duplicates -- and
// the nested foreach with a second iterator was rejected.
class pool;
  rand bit [3:0] q[$];
  rand bit [3:0] d[];
  rand bit [3:0] pair_q[$];
  constraint cq { q.size() inside {[3:6]}; unique {q}; }
  constraint cd { d.size() inside {[3:6]}; unique {d}; }
  constraint cp {
    pair_q.size() == 5;
    foreach (pair_q[i]) foreach (pair_q[j]) if (i < j) pair_q[i] != pair_q[j];
  }
endclass

module main;
  int errors;
  bit [3:0] arr[];
  bit [3:0] queue_v[$];
  initial begin
    pool p;
    p = new;
    repeat (100) begin
      if (!p.randomize()) begin $display("FAILED randomize"); errors++; end
      if (p.q.size() < 3 || p.q.size() > 6) begin $display("FAILED q size"); errors++; end
      if (p.d.size() < 3 || p.d.size() > 6) begin $display("FAILED d size"); errors++; end
      if (p.pair_q.size() != 5) begin $display("FAILED pair_q size"); errors++; end
      foreach (p.q[i]) foreach (p.q[j]) if (i < j && p.q[i] == p.q[j]) begin
        $display("FAILED q dup %p", p.q); errors++;
      end
      foreach (p.d[i]) foreach (p.d[j]) if (i < j && p.d[i] == p.d[j]) begin
        $display("FAILED d dup %p", p.d); errors++;
      end
      foreach (p.pair_q[i]) foreach (p.pair_q[j]) if (i < j && p.pair_q[i] == p.pair_q[j]) begin
        $display("FAILED nested foreach dup %p", p.pair_q); errors++;
      end
    end
    repeat (50) begin
      if (!std::randomize(arr) with { arr.size() inside {[3:6]}; unique {arr}; }) begin
        $display("FAILED std::randomize unique"); errors++;
      end
      foreach (arr[i]) foreach (arr[j]) if (i < j && arr[i] == arr[j]) begin
        $display("FAILED scope unique dup"); errors++;
      end
      if (!std::randomize(queue_v) with {
            queue_v.size() == 4;
            foreach (queue_v[i]) foreach (queue_v[j]) if (i < j) queue_v[i] != queue_v[j];
          }) begin
        $display("FAILED std::randomize nested foreach"); errors++;
      end
      foreach (queue_v[i]) foreach (queue_v[j]) if (i < j && queue_v[i] == queue_v[j]) begin
        $display("FAILED scope nested foreach dup"); errors++;
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
