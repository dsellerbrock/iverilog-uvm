module sv_if_violation_observed;
  bit [2:0] a = 3;
  event e;

  initial begin
    $display("D0");
    unique if (a == 0) ; else if (a == 1) ;
    $display("D1 same process");
  end

  initial begin
    #0;
    $display("D2 other process, Inactive");
  end

  initial begin
    #1;
    $display("F0");
    unique0 if (a == 0) ; else if (a == 1) ;
    @(e);
    $display("F1 resumed same step");
  end

  initial begin
    #1;
    #0;
    -> e;
  end

  initial begin
    #2;
    $display("P0");
    priority if (a == 0) ; else if (a == 1) ;
    $display("P1 same process");
  end

  initial begin
    #3;
    $display("G0");
    unique0 if (a == 0) ; else if (a == 1) ;
    #1;
    $display("G1");
  end
endmodule
