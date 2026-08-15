module sv_nettype_parameter_instance #(
  parameter int WIDTH = 1
)(
  output logic done
);
  nettype logic [WIDTH-1:0] parameter_net;
  parameter_net data;

  initial begin
    if ($bits(data) != WIDTH)
      $fatal(1, "parameterized nettype width mismatch: expected %0d, got %0d",
             WIDTH, $bits(data));
    done = 1'b1;
  end
endmodule

module sv_nettype_parameter_instances;
  wire narrow_done;
  wire wide_done;

  sv_nettype_parameter_instance #(.WIDTH(3)) narrow(narrow_done);
  sv_nettype_parameter_instance #(.WIDTH(11)) wide(wide_done);

  initial begin
    wait (narrow_done && wide_done);
    $display("PASSED");
  end
endmodule
