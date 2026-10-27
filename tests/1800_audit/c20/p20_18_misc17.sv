module p20_18_misc17;
  int r;
  string st;
  initial begin
    r = $system("exit 0"); $display("S0 %0d", r);
    r = $system("exit 3"); $display("S3 %0d", r);
    $system("echo SYS_SIDE_EFFECT");
  end
endmodule
