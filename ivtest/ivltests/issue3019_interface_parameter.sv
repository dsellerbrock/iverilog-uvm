interface class base;
  parameter int P = 4;
endclass
interface class other;
  parameter int Q = 9;
endclass
interface class child extends base; endclass
interface class middle extends child;
  parameter int P = 7;
endclass
interface class left extends middle; endclass
interface class right extends middle; endclass
interface class diamond extends left, right, other; endclass
interface class generic_base #(parameter int N = 3);
  parameter int R = N + 1;
endclass
interface class specialized extends generic_base #(12); endclass
module test;
  localparam int inherited = diamond::P;
  initial begin
    if (base::P != 4 || child::P != 4 || middle::P != 7 ||
        inherited != 7 || diamond::Q != 9 || specialized::R != 13)
      $fatal(1, "interface parameter lookup");
    $display("PASS");
  end
endmodule
