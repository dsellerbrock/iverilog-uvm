package issue3198_pkg;
  wire [3:0] driven;
  wire floating;
  tri1 pulled_up;
  wire (strong1, strong0) shared;
  nettype logic [3:0] word_net;
  word_net user_net;
endpackage

module issue3198_package_net;
  import issue3198_pkg::shared;
  reg a = 0, b = 0;
  assign issue3198_pkg::driven = 4'b1010;
  assign issue3198_pkg::user_net = 4'hc;
  assign shared = a;
  assign issue3198_pkg::shared = b;
  initial begin
    #1;
    if (issue3198_pkg::driven !== 4'b1010 ||
        issue3198_pkg::floating !== 1'bz ||
        issue3198_pkg::pulled_up !== 1'b1 || shared !== 1'b0 ||
        issue3198_pkg::user_net !== 4'hc)
      $fatal(1, "incorrect package net value");
    a = 1;
    #1;
    if (shared !== 1'bx) $fatal(1, "package net resolution failed");
    b = 1;
    #1;
    if (issue3198_pkg::shared !== 1'b1) $fatal(1, "package net update failed");
    $display("PASS");
  end
endmodule
