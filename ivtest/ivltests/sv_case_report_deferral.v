module sv_case_report_deferral;
  bit [2:0] a = 3;
  event e;

  initial begin
    $display("D0");
    unique case (a)
      0, 1: ;
    endcase
    priority case (a)
      0, 1: ;
    endcase
    unique case (1'b0)
      1'b0: ;
      1'b0: ;
    endcase
    $display("D1 same process");
  end

  initial begin
    #0;
    $display("D2 other process, Inactive");
  end

  initial begin
    #1;
    $display("F0");
    unique case (a)
      0, 1: ;
    endcase
    @(e);
    $display("F1 resumed same step");
  end

  initial begin
    #1;
    #0;
    -> e;
  end

  initial begin
    #3;
    $display("G0");
    unique case (a)
      0, 1: ;
    endcase
    #1;
    $display("G1");
  end
endmodule
