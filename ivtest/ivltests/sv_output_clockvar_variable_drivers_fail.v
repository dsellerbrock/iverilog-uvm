module sv_output_clockvar_continuous;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  assign q = 1'b0;
endmodule

module sv_output_clockvar_primitive;
  logic clk, a, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  buf b(q, a);
endmodule

module sv_output_clockvar_procedural_continuous;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  initial assign q = 1'b0;
endmodule

module sv_output_clockvar_force;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  initial force q = 1'b0;
endmodule

interface sv_output_clockvar_interface_if(input logic clk);
  logic q;
  assign q = 1'b0;
  clocking cb @(posedge clk);
    output q;
  endclocking
endinterface

module sv_output_clockvar_interface_continuous;
  logic clk;
  sv_output_clockvar_interface_if bus(clk);
endmodule

module sv_output_clockvar_module_output_child(output logic q);
  assign q = 1'b0;
endmodule

module sv_output_clockvar_module_output;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  sv_output_clockvar_module_output_child child(q);
endmodule

module sv_output_clockvar_part_select;
  logic clk;
  logic [3:0] q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  assign q[1:0] = 2'b0;
endmodule

interface sv_output_clockvar_hier_if(input logic clk);
  logic q;
  clocking cb @(posedge clk);
    output q;
  endclocking
endinterface

module sv_output_clockvar_hierarchical_continuous;
  logic clk;
  sv_output_clockvar_hier_if bus(clk);
  assign bus.q = 1'b0;
endmodule

module sv_output_clockvar_hierarchical_force;
  logic clk;
  sv_output_clockvar_hier_if bus(clk);
  initial force bus.q = 1'b1;
endmodule

module sv_output_clockvar_variable_drivers_fail;
  sv_output_clockvar_continuous c();
  sv_output_clockvar_primitive p();
  sv_output_clockvar_procedural_continuous pc();
  sv_output_clockvar_force f();
  sv_output_clockvar_interface_continuous ic();
  sv_output_clockvar_module_output mo();
  sv_output_clockvar_part_select ps();
  sv_output_clockvar_hierarchical_continuous hc();
  sv_output_clockvar_hierarchical_force hf();
  sv_output_clockvar_procedural procedural_ok();
endmodule

module sv_output_clockvar_procedural;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  initial q = 1'b0;
endmodule
