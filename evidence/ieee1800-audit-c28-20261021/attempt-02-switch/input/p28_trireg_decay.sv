module p28_trireg_decay;
  trireg (small) #(0, 0, 10) cd;
  reg drive = 1;

  assign cd = drive ? 1'b1 : 1'bz;

  initial begin
    #5 drive = 0;
    #9 $display("T14 %0t %v", $time, cd);
    #2 $display("T16 %0t %b", $time, cd);
  end
endmodule
