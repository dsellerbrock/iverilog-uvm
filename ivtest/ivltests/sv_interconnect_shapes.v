module sv_interconnect_shapes_driver #(parameter bit VALUE = 1'b0)(
  output wire out
);
  assign out = VALUE;
endmodule

module sv_interconnect_shapes_sink(
  input wire packed_3,
  input wire packed_2,
  input wire packed_1,
  input wire packed_0,
  input wire unpacked_0,
  input wire unpacked_1
);
  initial begin
    #1;
    if ({packed_3, packed_2, packed_1, packed_0} !== 4'ha ||
        unpacked_0 !== 1'b1 || unpacked_1 !== 1'b0)
      $fatal(1, "shaped interconnect value mismatch");
    $display("PASSED");
  end
endmodule

module sv_interconnect_shapes;
  interconnect [3:0] packed_links;
  interconnect unpacked_links [0:1];

  sv_interconnect_shapes_driver #(.VALUE(1'b1)) packed_driver_3(packed_links[3]);
  sv_interconnect_shapes_driver #(.VALUE(1'b0)) packed_driver_2(packed_links[2]);
  sv_interconnect_shapes_driver #(.VALUE(1'b1)) packed_driver_1(packed_links[1]);
  sv_interconnect_shapes_driver #(.VALUE(1'b0)) packed_driver_0(packed_links[0]);
  sv_interconnect_shapes_driver #(.VALUE(1'b1)) unpacked_driver_0(unpacked_links[0]);
  sv_interconnect_shapes_driver #(.VALUE(1'b0)) unpacked_driver_1(unpacked_links[1]);

  sv_interconnect_shapes_sink sink(
    packed_links[3],
    packed_links[2],
    packed_links[1],
    packed_links[0],
    unpacked_links[0],
    unpacked_links[1]
  );
endmodule
