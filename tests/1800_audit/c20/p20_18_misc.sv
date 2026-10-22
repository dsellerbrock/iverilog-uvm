module p20_18_misc;
  int r;
  string st;
  task automatic leaf();
    $stacktrace;
    st = $stacktrace;
  endtask
  initial begin
    r = $system("exit 0"); $display("S0 %0d", r);
    r = $system("exit 3"); $display("S3 %0d", r);
    $system("echo SYS_SIDE_EFFECT");
    leaf(); $display("ST %0d", st.len() > 0);
  end
endmodule
