program tb;
  task hello();
    $display("HELLO");
  endtask
endprogram

module top;
  initial begin
    #1 tb.hello();
  end
endmodule
