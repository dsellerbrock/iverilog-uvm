module sub2 #(parameter p1 = 1, parameter type p2 = shortint);
  p2 j = 0;
  initial $display("SUB2 p1=%0d bits=%0d", p1, $bits(j));
endmodule
module sub3 #(parameter A = 1, localparam B = A + 1, parameter C = 5);
  initial $display("SUB3 A=%0d B=%0d C=%0d", A, B, C);
endmodule
class K; int a; function new(int a0); a = a0; endfunction endclass
module p06_20b;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  localparam byte colon1 = ":";
  specparam dhold = 1.0;
  const int ci = 5;
  const K obj = new(5);
  real rr;
  sub2 #(.p1(3), .p2(int)) v1();
  sub2 v2();
  sub3 #(.A(10), .C(7)) v3();
  task automatic ct(int a); const int c2 = a * 2; $display("INFO const_auto=%0d (expect %0d)", c2, a * 2); endtask
  initial begin
    ck("localparam_byte", colon1 == 8'h3a);
    rr = dhold + 1.0; ck("specparam_expr", rr == 2.0);
    ck("const_static", ci == 5);
    ck("const_handle_member", obj.a == 5);
    obj.a = 7; ck("const_handle_member_write", obj.a == 7);
    ct(4);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
