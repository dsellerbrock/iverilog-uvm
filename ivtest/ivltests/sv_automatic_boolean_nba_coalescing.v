module main;
  int wakes;
  bit x,y;
  task automatic watch();
    bit mask;
    mask=1;
    fork
      begin @(negedge((x | y) & mask)); wakes++; end
      begin #2; end
    join_any
    disable fork;
  endtask
  initial begin
    repeat (3) begin
      x=1; y=0;
      fork watch(); watch(); begin #1; x<=0; y<=1; end join
    end
    if(wakes) $fatal(1,"NBA updates exposed transient Boolean value: %0d",wakes);
    $display("PASSED");
    $finish(0);
  end
  initial begin #100; $fatal(1,"timeout"); end
endmodule
