// IEEE 1800-2023 25.6: interface signals reached through a modport port
// are module path terminals. The interface instance "i" sorts before the
// module instance "u", which used to abort the compiler (the path's scope
// was looked up before it was emitted).
interface itf;
  logic a;
  wire  y;
  modport m(input a, output y);
endinterface

module buf1(itf.m ch);
  assign ch.y = ch.a;
  specify
    (ch.a => ch.y) = 5;
  endspecify
endmodule

module top;
  itf i();
  buf1 u(i.m);
  reg fail = 0;
  initial begin
    i.a = 0;
    #10 i.a = 1;
    #1 if (i.y !== 1'b0) begin $display("FAILED: t=%0t y=%b", $time, i.y); fail = 1; end
    #5 if (i.y !== 1'b1) begin $display("FAILED: t=%0t y=%b", $time, i.y); fail = 1; end
    if (!fail) $display("PASSED");
  end
endmodule
