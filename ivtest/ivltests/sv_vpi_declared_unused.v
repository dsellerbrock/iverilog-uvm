module sv_vpi_declared_unused;
  logic [7:0] unused_logic;
  reg [7:0] unused_reg;
  logic [3:0] live;

  initial begin
    live = 4'hA;
    #1 $check_declared_variables;
  end
endmodule
