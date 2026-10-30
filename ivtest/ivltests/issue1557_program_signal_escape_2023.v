program p;
  int secret;
  initial secret = 1;
endprogram
module tb;
  p pi();
  initial $display("external=%0d", pi.secret);
endmodule
