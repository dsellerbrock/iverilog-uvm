class A;
endclass
class Bq;
endclass
module test;
  A a;
  Bq b;
  initial begin
    if (a == b) $display("==");
    if (a != b) $display("!=");
    if (a === b) $display("===");
    if (a !== b) $display("!==");
  end
endmodule
