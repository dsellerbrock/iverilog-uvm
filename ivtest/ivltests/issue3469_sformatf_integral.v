module issue3469_sformatf_integral;
  reg [47:0] fmt = "%0d-%h";
  reg [63:0] wrapped = "xx%0d-%h";
  wire [47:0] net_fmt = fmt;

  task check(input string actual, input string expected);
    if (actual != expected) begin
      $display("FAIL: got [%s], expected [%s]", actual, expected);
      $fatal(1);
    end
  endtask

  initial begin
    check($sformatf(fmt, 12, 8'hab), "12-ab");
    check($sformatf(net_fmt, 12, 8'hab), "12-ab");
    check($sformatf(wrapped[47:0], 12, 8'hab), "12-ab");
    check($sformatf({fmt[47:24], fmt[23:0]}, 12, 8'hab), "12-ab");
    check($sformatf(48'h2530642d2568, 12, 8'hab), "12-ab");
    fmt = "[%s]  ";
    check($sformatf(fmt, "%d"), "[%d]  ");
    check($sformatf("%s", "%h"), "%h");
    check($sformatf("literal"), "literal");
    $display("PASSED");
  end
endmodule
