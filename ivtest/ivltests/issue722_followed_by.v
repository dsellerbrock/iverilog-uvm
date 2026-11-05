module issue722_followed_by;
  bit clk = 0;
  bit run_ov = 0, run_nov = 0, run_seq = 0, run_missing = 0;
  bit run_empty = 0;
  bit a = 0, b = 0, c = 0, d = 0;
  bit x = 0, y = 0, z = 0, empty_consequent = 0;
  int ov_fail = 0, nov_fail = 0, seq_fail = 0, missing_fail = 0;
  int empty_pass = 0, empty_fail = 0;

  sequence empty_sequence;
    1'b1[*0];
  endsequence

  always #5 clk = ~clk;

  ap_overlapped: assert property (@(posedge clk) disable iff (!run_ov)
                                  (a #-# b))
    else ov_fail++;
  ap_nonoverlapped: assert property (@(posedge clk) disable iff (!run_nov)
                                     (c #=# d))
    else nov_fail++;
  ap_sequence_consequent: assert property (@(posedge clk) disable iff (!run_seq)
                                           (x #-# (y ##1 z)))
    else seq_fail++;
  ap_requires_antecedent: assert property (@(posedge clk) disable iff (!run_missing)
                                           (1'b0 #-# 1'b1))
    else missing_fail++;
  ap_empty_nonoverlapped: assert property (@(posedge clk) disable iff (!run_empty)
                                           (empty_sequence #=# empty_consequent))
    empty_pass++; else empty_fail++;

  initial begin
    #1;
    run_ov = 1;
    a = 1;
    b = 1;
    run_nov = 1;
    c = 1;
    d = 0;
    run_seq = 1;
    x = 1;
    y = 1;
    z = 1;
    run_empty = 1;
    empty_consequent = 1;

    @(negedge clk);
    b = 0;
    d = 1;
    run_missing = 1;
    empty_consequent = 0;

    @(negedge clk);
    run_ov = 0;
    run_missing = 0;
    run_empty = 0;

    @(negedge clk);
    run_nov = 0;
    run_seq = 0;

    repeat (2) @(negedge clk);
    if (ov_fail != 1 || nov_fail != 0 || seq_fail != 0 || missing_fail != 1
        || empty_pass != 1 || empty_fail != 1)
      $fatal(1, "followed-by counts: ov=%0d nov=%0d seq=%0d missing=%0d empty-pass=%0d empty-fail=%0d",
             ov_fail, nov_fail, seq_fail, missing_fail, empty_pass, empty_fail);
    $display("PASSED: followed-by endpoint, sequence, and non-vacuity checks");
    $finish(0);
  end
endmodule
