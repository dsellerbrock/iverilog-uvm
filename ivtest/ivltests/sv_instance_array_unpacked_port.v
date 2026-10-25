module sv_instance_array_unpacked_child(input logic [7:0] d,
                                         output wire [7:0] q);
  assign q = d + 1;
endmodule

module sv_instance_array_unpacked_port;
  logic [7:0] d[1:0];
  wire [7:0] q[1:0];

  sv_instance_array_unpacked_child c[0:1](.d(d), .q(q));

  initial begin
    d[0] = 8'h20;
    d[1] = 8'h10;
    #1;
    if (q[1] !== 8'h11 || q[0] !== 8'h21)
      $fatal(1, "element mapping failed: q[1]=%h q[0]=%h", q[1], q[0]);
    $display("PASS: q[1]=%h q[0]=%h", q[1], q[0]);
  end
endmodule
