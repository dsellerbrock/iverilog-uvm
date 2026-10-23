module timing_check_skew_flags;
  reg ref_dormant = 0, data_dormant = 0;
  reg ref_condition = 0, data_condition = 0, mode_condition = 1;
  reg ref_active = 0, data_active = 0;
  reg ref_full = 0, data_full = 0;
  reg n_dormant = 0, n_condition = 0, n_active = 0, n_full = 0;
  integer count_dormant = 0, count_condition = 0;
  integer count_active = 0, count_full = 0;

  parameter EVENT_BASED = 1'b1;
  parameter REMAIN_DORMANT = 1'b0;
  parameter REMAIN_ACTIVE = 1'b1;

  specify
    $timeskew(posedge ref_dormant, posedge data_dormant, 2,
              n_dormant, EVENT_BASED, REMAIN_DORMANT);
    $timeskew(posedge ref_condition &&& mode_condition,
              posedge data_condition, 2, n_condition,
              EVENT_BASED, REMAIN_DORMANT);
    $timeskew(posedge ref_active, posedge data_active, 2,
              n_active, EVENT_BASED, REMAIN_ACTIVE);
    $fullskew(posedge ref_full, posedge data_full, 2, 2,
              n_full, EVENT_BASED, REMAIN_ACTIVE);
  endspecify

  always @(n_dormant) count_dormant = count_dormant + 1;
  always @(n_condition) count_condition = count_condition + 1;
  always @(n_active) count_active = count_active + 1;
  always @(n_full) count_full = count_full + 1;

  initial begin
    #1 ref_dormant = 1; ref_condition = 1;
       ref_active = 1; ref_full = 1;
    #1 ref_dormant = 0; mode_condition = 0;
       ref_condition = 0; ref_active = 0; ref_full = 0;
    #1 ref_condition = 1;
    #1 ref_condition = 0;
    #1 data_condition = 1;
    data_dormant = 1; data_active = 1; data_full = 1;
    #1 data_dormant = 0; data_active = 0; data_full = 0;
    #1 data_dormant = 1; data_active = 1; data_full = 1;
    #1 ref_dormant = 1;
    #1 ref_dormant = 0;
    #4 data_dormant = 0;
    #1 data_dormant = 1;
    #1;

    if (count_dormant != 2 || count_condition != 0
        || count_active != 2 || count_full != 2)
      $fatal(1, "unexpected skew violation counts: %0d %0d %0d %0d",
             count_dormant, count_condition, count_active, count_full);
    $display("PASS: skew event flags and remain-active behavior");
    $finish;
  end
endmodule
