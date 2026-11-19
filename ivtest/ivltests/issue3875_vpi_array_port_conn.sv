module bit_port(input wire a);
endmodule

module vector_ports(input wire [1:0] a, output wire [1:0] y, input wire open);
  assign y = ~a;
endmodule

module compound_port(.a({hi, lo}));
  input wire hi, lo;
endmodule

module top;
  reg [3:0] stimulus = 4'b1001;
  wire [1:0] g = stimulus[3:2];
  wire [8:11] ascending = stimulus;
  wire [-2:-5] driven;

  bit_port ar[1:0](g);
  vector_ports split[2:3](ascending, driven, );
  vector_ports whole[1:0](g, , );
  compound_port compound_split[2:3](ascending);
  compound_port broadcast[1:0](g);
  compound_port one[7:7](g);

  initial begin
    #1 $probe_array_port_conn;
    if ({broadcast[1].hi, broadcast[1].lo} !== 2'b10 ||
        {broadcast[0].hi, broadcast[0].lo} !== 2'b10 ||
        {compound_split[2].hi, compound_split[2].lo} !== 2'b10 ||
        {compound_split[3].hi, compound_split[3].lo} !== 2'b01)
      $fatal(1, "incorrect compound port wiring");
    stimulus = 4'b0111;
    #1 $probe_array_port_conn;
  end
endmodule
