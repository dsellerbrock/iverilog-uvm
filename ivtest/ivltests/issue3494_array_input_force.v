module issue3494_sink(input wire [1:0] a);
endmodule

module issue3494_scalar_sink(input wire a);
endmodule

module issue3494_array_input_force;
  reg [1:0] source = 2'b11;
  reg scalar = 1'b1;
  issue3494_scalar_sink scalar_array [1:0] (scalar);
  reg [3:0] split = 4'b1001;
  issue3494_sink broadcast [1:0] (source);
  issue3494_sink divided [1:0] (split);
  issue3494_sink plain (source);

  initial begin
    #1;
    if (broadcast[0].a !== 2'b11 || broadcast[1].a !== 2'b11 ||
        divided[0].a !== 2'b01 || divided[1].a !== 2'b10)
      $fatal(1, "initial values");
    force scalar_array[0].a = 1'b0;
    force broadcast[0].a = 2'b00;
    force divided[0].a = 2'b11;
    #1;
    if (scalar !== 1'b1 || scalar_array[0].a !== 1'b0 ||
        scalar_array[1].a !== 1'b1 || source !== 2'b11 || broadcast[0].a !== 2'b00 ||
        broadcast[1].a !== 2'b11 || plain.a !== 2'b11 ||
        split !== 4'b1001 || divided[0].a !== 2'b11 ||
        divided[1].a !== 2'b10)
      $fatal(1, "force leaked across input ports");
    source = 2'b10;
    #1;
    if (broadcast[0].a !== 2'b00 || broadcast[1].a !== 2'b10 ||
        plain.a !== 2'b10 || source !== 2'b10)
      $fatal(1, "source change while forced");
    release scalar_array[0].a;
    release broadcast[0].a;
    release divided[0].a;
    #1;
    if (scalar_array[0].a !== 1'b1 || scalar_array[1].a !== 1'b1 ||
        broadcast[0].a !== 2'b10 || broadcast[1].a !== 2'b10 ||
        divided[0].a !== 2'b01 || divided[1].a !== 2'b10)
      $fatal(1, "release did not restore drivers");
    $display("PASS");
    $finish;
  end
endmodule
