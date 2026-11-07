// IEEE 1800-2017/2023 37.17 / 38.23: vpi_iterate(vpiVariables, module)
// returns every variable of the module, including logic/reg variables
// (vpiLogicVar), variable arrays and variable ports, and no nets.
module issue887_vpi_variables(output logic [3:0] y);
  logic [7:0] v;
  reg [3:0] r;
  int i;
  logic [1:0] mem [4];
  wire w;
  wire [1:0] nw [2];

  assign w = v[0];
  initial begin
    v = 8'h5a; r = 4'h3; i = 7; mem[0] = 2'b01; y = 4'h9;
    #1 $display("%h %h %0d %b %b %h", v, r, i, mem[0], w, y);
    $check_vpi_variables;
  end
endmodule
