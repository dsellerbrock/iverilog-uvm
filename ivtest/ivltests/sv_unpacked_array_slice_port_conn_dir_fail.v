// Companion negative to sv_unpacked_array_slice_port_conn.v: a slice
// range spelled in the opposite direction from the array's declared
// range must still be rejected, unchanged by the port-connection
// array-slice fix.
module sub #(parameter WIDTH = 4) (
  input [1:0] r0 [WIDTH-1:0]
);
endmodule

module main;
  logic [1:0] arr [0:4];  // ascending declared range

  sub #(.WIDTH(4)) u_sub (
    .r0(arr[3:0])          // descending slice on an ascending array
  );
endmodule
