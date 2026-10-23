primitive and_udp (o, a, b);
  output o;
  input a, b;
  table
    0 ? : 0;
    ? 0 : 0;
    1 1 : 1;
  endtable
endprimitive

module sv_udp_instance_array;
  reg [1:0] a;
  reg common;
  wire [1:0] q;
  and_udp ua[1:0](q, a, common);

  initial begin
    a = 2'b00;
    common = 1'b1;
    #1;
    if (q !== 2'b00) $fatal(1, "initial UDP array output: %b", q);
    a = 2'b10;
    #1;
    if (q !== 2'b10) $fatal(1, "bit-sliced UDP array output: %b", q);
    common = 1'b0;
    #1;
    if (q !== 2'b00) $fatal(1, "replicated UDP input output: %b", q);
    $display("PASSED");
    $finish;
  end
endmodule
