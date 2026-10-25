// IEEE 1800-2017 25.5.4: modport expressions may concatenate members.
interface I;
  logic [7:0] r = 8'hAB;
  modport A (output .P({r[3:0], r[7:4]}),
             input .Q({r[3:0], r[7:4]}));
endinterface
module M(interface i);
  initial begin
    i.P = 8'h12;
    #1;
    if (i.Q !== 8'h12) $fatal(1, "modport concatenation read failed");
  end
endmodule
module sv_modport_expression_concat_2017;
  I i();
  M m(i.A);
  initial begin
    #2;
    if (i.r !== 8'h21) $fatal(1, "modport concatenation write failed");
    $display("PASSED");
  end
endmodule
