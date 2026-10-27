interface modport_undeclared_if;
  wire present;
  modport view(input missing);
endinterface
module sv_modport_undeclared_signal;
  modport_undeclared_if bus();
endmodule
