// Elaborating VIF types with no concrete interface instances must provide
// interface-local enum literals and constant functions to output-skew folding.
interface clocking_enum_skew_type_only_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;
  typedef enum integer { LOCAL_ENUM_SKEW = 3 } skew_t;
  logic raw;
  clocking cb @(posedge clk);
    output #LOCAL_ENUM_SKEW raw;
  endclocking
endinterface

interface clocking_function_skew_type_only_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;
  logic raw;

  function automatic integer local_skew();
    return 4;
  endfunction

  clocking cb @(posedge clk);
    output #(local_skew()) raw;
  endclocking
endinterface

module sv_clocking_vif_skew_type_only;
  timeunit 1ns;
  timeprecision 1ps;

  virtual clocking_enum_skew_type_only_if enum_vif;
  virtual clocking_function_skew_type_only_if function_vif;

  initial begin
    $display("PASSED");
    $finish;
  end
endmodule
