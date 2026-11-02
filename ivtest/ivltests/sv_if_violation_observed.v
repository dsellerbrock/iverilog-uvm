module sv_if_violation_observed;
  bit [2:0] k = 3;
  logic z;
  event e;

  initial begin
    #1;
    unique if (k == 0) z = 0;
    else if (k == 1) z = 1;
    $display("unique-if same process");
  end

  initial begin
    #1;
    #0;
    $display("other process, Inactive region");
  end

  initial begin
    #2;
    unique if (k == 0) z = 0;
    else if (k == 1) z = 1;
    @(e);
    $display("unique-if resumed in same time step");
  end

  initial begin
    #2;
    #0;
    -> e;
  end

  initial begin
    #3;
    unique0 if (k == 3) z = 0;
    else if (k == 3) z = 1;
    $display("unique0-if same process");
  end

  initial begin
    #4;
    priority if (k == 0) z = 0;
    else if (k == 1) z = 1;
    $display("priority-if same process");
  end
endmodule
