module sv_clocking_instantiated_default_cycle_delay_child;
  initial ##1;
endmodule

module sv_clocking_instantiated_default_cycle_delay_fail_2017;
  logic clk;
  default clocking cb @(posedge clk); endclocking
  sv_clocking_instantiated_default_cycle_delay_child child();
endmodule
