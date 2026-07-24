module top;
  initial begin : blk
    automatic event ea; static event es;
    fork begin #1 ->ea; end join_none
    @ea $display("PASS");
    $finish(0);
  end
endmodule
