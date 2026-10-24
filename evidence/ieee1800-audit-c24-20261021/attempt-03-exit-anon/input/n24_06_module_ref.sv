package pk;
  program;
    task automatic hello();
      $display("ANON %0t", $time);
    endtask
  endprogram
endpackage

module m;
  import pk::*;
  initial #1 hello();
endmodule
