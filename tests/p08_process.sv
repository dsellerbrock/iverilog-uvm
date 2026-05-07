// G07: process introspection — status() after kill()
module p08_process;
  process p;
  int status_val;

  initial begin
    fork
      begin
        p = process::self();
        #100;
      end
    join_none
    #1;
    p.kill();
    #1;
    status_val = p.status();
    $display("status=%0d KILLED=%0d", status_val, int'(process::KILLED));
    if (status_val == int'(process::KILLED))
      $display("PASS");
    else
      $display("FAIL");
  end
endmodule
