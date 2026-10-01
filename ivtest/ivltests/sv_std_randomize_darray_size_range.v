// std::randomize() of a dynamic array or queue whose size is constrained to a
// range (IEEE 1800-2017/2023 18.12): the size is a random choice among the
// feasible values. Dynamic arrays were rejected, and a ranged size was an
// error (OpenTitan usbdev: std::randomize(tx_data) with
// { tx_data.size() <= MaxPktSizeByte; }).
module test;
  localparam int MaxPktSizeByte = 8;
  initial begin
    byte unsigned d[];
    byte unsigned q[$];
    bit [7:0] empty_q[$];
    bit [7:0] bounded_q[$:1];
    bit [7:0] guarded_q[$];
    bit [7:0] sparse_q[$];
    int seen[int];
    int seen_bounded[int];
    int seen_guarded[int];
    bit ok, all_ok;
    all_ok = 1;
    repeat (200) begin
      ok = std::randomize(d) with { d.size() <= MaxPktSizeByte; d.size() > 0; };
      all_ok &= ok && d.size() >= 1 && d.size() <= MaxPktSizeByte;
      seen[d.size()] = 1;
    end
    ok = std::randomize(q) with { q.size() inside {[2:3]}; };
    all_ok &= ok && (q.size() == 2 || q.size() == 3);
    repeat (20) begin
      ok = std::randomize(empty_q) with {
        empty_q.size() inside {[0:1]};
        foreach (empty_q[i]) empty_q[i] == 8'h00 && empty_q[i] == 8'h01;
      };
      all_ok &= ok && empty_q.size() == 0;
    end
    repeat (40) begin
      ok = std::randomize(bounded_q) with {
        bounded_q.size() inside {[1:3]};
      };
      all_ok &= ok && (bounded_q.size() == 1 || bounded_q.size() == 2);
      seen_bounded[bounded_q.size()] = 1;
    end
    repeat (40) begin
      ok = std::randomize(guarded_q) with {
        guarded_q.size() inside {[0:1]};
        if (guarded_q.size() == 1) guarded_q[0] == 8'h01;
      };
      all_ok &= ok && (guarded_q.size() == 0 ||
                       (guarded_q.size() == 1 && guarded_q[0] == 8'h01));
      seen_guarded[guarded_q.size()] = 1;
    end
    ok = std::randomize(sparse_q) with {
      sparse_q.size() inside {0, 1025};
      foreach (sparse_q[i]) sparse_q[i] == 8'h00 && sparse_q[i] == 8'h01;
    };
    all_ok &= ok && sparse_q.size() == 0;
    if (all_ok && seen.num() > 1 && seen_bounded.num() == 2 &&
        seen_guarded.num() == 2)
      $display("PASSED");
    else $display("FAILED %0d %0d %0d %0d", all_ok, seen.num(),
                  seen_bounded.num(), seen_guarded.num());
  end
endmodule
