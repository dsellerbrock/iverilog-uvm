// IEEE 1800-2017/2023 25.5.4 and 11.4.12: selects on a named modport
// expression apply to the expression value when it is read.
interface I;
  logic [3:0] a = 4'h5, b = 4'ha;
  modport OUT (output .R({a, b}));
endinterface

module Wr(interface i);
  initial #1 i.R = {4'h7, i.R[3:0]};
endmodule

module sv_modport_expression_concat_read_modify_write;
  I i();
  Wr w(i.OUT);
  initial begin
    #2;
    if (i.a !== 4'h7 || i.b !== 4'ha)
      $fatal(1, "read-modify-write through concatenated modport failed: a=%h b=%h",
             i.a, i.b);
    $display("PASSED");
  end
endmodule
