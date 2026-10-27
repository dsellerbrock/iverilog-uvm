program pg;
  initial begin
    #1 $exit;
  end
  initial begin
    #5 $display("PROG2 done");
  end
endprogram

module m;
  initial begin
    #20 $display("LATE");
  end
endmodule
