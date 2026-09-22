module core_ordinary_control;
  logic a;
  logic [3:0] b;
  int wakes;
  initial begin
    fork begin @(a, b); wakes++; end join_none
    #1 a = 1'b1;
    #1 if (wakes != 1) $fatal(1, "ordinary first leaf missed");
    fork begin @(a or b); wakes++; end join_none
    #1 b = 4'hc;
    #1 if (wakes != 2) $fatal(1, "ordinary second leaf missed");
    $display("PASS core ordinary control"); $finish;
  end
endmodule
