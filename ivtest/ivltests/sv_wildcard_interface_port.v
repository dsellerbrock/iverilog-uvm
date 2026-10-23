interface simple_bus;
  logic req;
endinterface

module memMod(simple_bus sb_intf, input logic clk, output logic seen);
  always_comb seen = sb_intf.req & clk;
endmodule

module sv_wildcard_interface_port;
  logic clk = 1'b1;
  logic seen;
  simple_bus sb_intf();

  memMod mem (.*);

  initial begin
    sb_intf.req = 1'b1;
    #1;
    if (seen !== 1'b1) begin
      $display("FAILED: implicit interface port connection seen=%b", seen);
      $finish;
    end
    $display("PASS");
    $finish;
  end
endmodule
