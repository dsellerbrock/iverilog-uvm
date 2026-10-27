module top;
  int s;
  task automatic t(ref static int x); x = 5; endtask
  initial begin
    t(s);
    $display("%s 13.5.2.ref_static", s == 5 ? "PASS" : "FAIL");
  end
endmodule
