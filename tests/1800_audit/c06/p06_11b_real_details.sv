module p06_11b;
  shortreal sr; realtime rt; real r;
  initial begin
    sr=1.5; rt=3.25; r=rt;
    $display("SHORT value=%0.9f bits=%0d eq=%0d", sr, $bits(sr), sr==1.5);
    $display("REALTIME value=%0.9f bits=%0d eq=%0d real_bits=%0d", rt, $bits(rt), rt==3.25, $bits(r));
    $display("REAL_FROM_RT value=%0.9f eq=%0d", r, r==3.25);
  end
endmodule
