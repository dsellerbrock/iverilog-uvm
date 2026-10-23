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

module sv_output_clockvar_variable_drivers_fail;
  sv_output_clockvar_continuous c();
  sv_output_clockvar_primitive p();
  sv_output_clockvar_procedural_continuous pc();
  sv_output_clockvar_procedural procedural_ok();
endmodule

module sv_output_clockvar_procedural;
  logic clk, q;
  clocking cb @(posedge clk);
    output q;
  endclocking
  initial q = 1'b0;
endmodule
