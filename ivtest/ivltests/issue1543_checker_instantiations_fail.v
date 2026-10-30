// IEEE 1800-2017/2023 17.2 prohibits module, interface, and program
// instantiations in a checker while permitting nested checker instances.
checker issue1543_inner;
endchecker

checker issue1543_outer;
  issue1543_inner nested_checker();
  issue1543_leaf module_instance();
  issue1543_bus interface_instance();
  issue1543_driver program_instance();
endchecker

module issue1543_leaf;
endmodule

interface issue1543_bus;
endinterface

program issue1543_driver;
endprogram

module issue1543_top;
endmodule
