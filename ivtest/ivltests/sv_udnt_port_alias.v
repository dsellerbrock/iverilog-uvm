nettype logic nt_a;
nettype nt_a nt_alias;

module sv_udnt_port_alias_sink(input nt_a p);
  initial $display("port=%b", p);
endmodule

module sv_udnt_port_alias;
  nt_alias actual;
  assign actual = 1'b1;
  sv_udnt_port_alias_sink dut(.p(actual));
  initial begin
    #1 $finish;
  end
endmodule
