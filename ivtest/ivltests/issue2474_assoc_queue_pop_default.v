// IEEE 1800-2017/2023 7.9.11: mutating a missing entry that reads as the
// default queue must create an independent entry and leave the default intact.
module issue2474_assoc_queue_pop_default;
  typedef int q_t[$];
  q_t m[int] = '{default: '{3, 1, 2}};
  int popped;

  initial begin
    popped = m[17].pop_back();
    if (popped != 2 || m.num() != 1 || !m.exists(17) ||
        m[17].size() != 2 || m[17][0] != 3 || m[17][1] != 1 ||
        m[99].size() != 3 || m[99][0] != 3 || m[99][1] != 1 ||
        m[99][2] != 2)
      $fatal(1, "default queue changed or entry was not materialized");
    $display("PASSED");
  end
endmodule
