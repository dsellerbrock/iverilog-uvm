module t;
  logic [3:0][17:4] v;          // inner LSB 4
  logic [3:0][13:0] z;          // inner LSB 0 control
  logic [3:0][17:4] w_ac, w_as; // element writes: always_comb vs assign
  logic [3:0][17:4] w_part;     // part-select write inside element
  logic [13:0] rd_const, rd_gen [4];
  initial begin
    v = {14'h2003, 14'h2002, 14'h2001, 14'h2000};
    z = v;
  end
  assign rd_const = v[3];                          // constant element read
  for (genvar i = 0; i < 4; i++) begin : g
    assign rd_gen[i] = v[i];                       // genvar element read
    always_comb w_ac[i] = z[i];                    // element write (always_comb)
    assign w_as[i] = z[i];                         // element write (continuous)
    assign w_part[i][4+:14] = z[i];                // indexed part-select write
  end
  initial begin
    #1;
    $display("flat v=%h", v);
    $display("READ  const v[3]=%h (2003)   genvar v[0..3]=%h %h %h %h", rd_const, rd_gen[0], rd_gen[1], rd_gen[2], rd_gen[3]);
    $display("WRITE always_comb w[i]=z[i]: %h   (want %h)", w_ac, v);
    $display("WRITE assign      w[i]=z[i]: %h", w_as);
    $display("WRITE part [i][4+:14]=z[i]: %h", w_part);
  end
endmodule
