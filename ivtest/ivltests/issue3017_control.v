interface class api #(int WIDTH = 2);
  parameter int DOUBLE = WIDTH * 2;
endclass
class cls #(int WIDTH = 2);
  parameter int DOUBLE = WIDTH * 2;
endclass
class payload;
  parameter int VALUE = 1;
  int field;
endclass
class wrapper #(int WIDTH = 2);
  static payload obj;
endclass
module test;
  initial begin
    if (api#(.WIDTH(3))::DOUBLE != 6 || cls#(3)::DOUBLE != 6)
      $fatal(1, "class body parameter value is incorrect");
    wrapper#(3)::obj = new;
    wrapper#(3)::obj.field = 7;
    if (wrapper#(3)::obj.field != 7)
      $fatal(1, "class member specialization is incorrect");
    $display("PASS");
  end
endmodule
