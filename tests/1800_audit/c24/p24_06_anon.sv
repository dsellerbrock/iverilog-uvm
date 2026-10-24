package pk;
  program;
    task automatic hello();
      $display("ANON %0t", $time);
    endtask
  endprogram
endpackage

program top;
  import pk::*;
  initial begin
    #1 hello();
  end
endprogram
