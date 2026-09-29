class draw;
  rand bit [3:0] value;
endclass
module top;
  draw item;
  string testname;
  initial begin
    item = new();
    if (!(item.randomize() with { value == 4'd3; })) $fatal(1, "randomize failed");
    if (!$value$plusargs("TESTNAME=%s", testname)) $fatal(1, "missing TESTNAME");
    if (testname != "readbasic" || item.value != 4'd3) $fatal(1, "bad value");
    $display("PASSED");
  end
endmodule
