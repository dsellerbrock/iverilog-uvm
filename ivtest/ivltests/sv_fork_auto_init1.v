module test;
  task automatic t;
    int ph = 7;
    fork
      automatic int phase = ph;
      begin
        if (phase !== 7)
          $display("FAIL phase=%0d", phase);
        else
          $display("PASSED");
      end
    join_none
    #0;
  endtask

  initial begin
    t();
  end
endmodule
