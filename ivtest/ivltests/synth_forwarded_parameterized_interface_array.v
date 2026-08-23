interface forwarded_array_if #(parameter int WIDTH = 8);
  wire [WIDTH-1:0] down;
  wire [WIDTH-1:0] up;

  modport link(output down, input up);
endinterface

module forwarded_array_leaf(
  forwarded_array_if.link ports [4:5],
  input  logic [15:0] down_left,
  input  logic [15:0] down_right,
  output logic [15:0] seen_up_left,
  output logic [15:0] seen_up_right
);
  function automatic int left_port();
    return 4;
  endfunction

  function automatic int right_port();
    return 5;
  endfunction

  // Constant-function owner indices remain statically resolvable even though
  // the general interface-array l-value path preserves run-time expressions.
  assign ports[left_port()].down = down_left;
  assign ports[right_port()].down = down_right;
  assign seen_up_left = ports[4].up;
  assign seen_up_right = ports[5].up;
endmodule

module forwarded_array_middle(
  forwarded_array_if.link ports [1:0],
  input  logic [15:0] down_left,
  input  logic [15:0] down_right,
  output logic [15:0] seen_up_left,
  output logic [15:0] seen_up_right
);
  forwarded_array_leaf leaf(
    .ports(ports),
    .down_left(down_left),
    .down_right(down_right),
    .seen_up_left(seen_up_left),
    .seen_up_right(seen_up_right)
  );
endmodule

module forwarded_array_outer(
  forwarded_array_if.link ports [0:1],
  input  logic [15:0] down_left,
  input  logic [15:0] down_right,
  output logic [15:0] seen_up_left,
  output logic [15:0] seen_up_right
);
  forwarded_array_middle middle(
    .ports(ports),
    .down_left(down_left),
    .down_right(down_right),
    .seen_up_left(seen_up_left),
    .seen_up_right(seen_up_right)
  );
endmodule

module synth_forwarded_parameterized_interface_array_netlist(
  input  logic [15:0] down_left,
  input  logic [15:0] down_right,
  input  logic [15:0] up_left,
  input  logic [15:0] up_right,
  output logic [15:0] seen_down_left,
  output logic [15:0] seen_down_right,
  output logic [15:0] seen_up_left,
  output logic [15:0] seen_up_right
);
  forwarded_array_if #(.WIDTH(16)) bus [3:2] ();

  assign bus[3].up = up_left;
  assign bus[2].up = up_right;
  forwarded_array_outer outer(
    .ports(bus),
    .down_left(down_left),
    .down_right(down_right),
    .seen_up_left(seen_up_left),
    .seen_up_right(seen_up_right)
  );
  assign seen_down_left = bus[3].down;
  assign seen_down_right = bus[2].down;
endmodule

module synth_forwarded_parameterized_interface_array;
  logic [15:0] down_left;
  logic [15:0] down_right;
  logic [15:0] up_left;
  logic [15:0] up_right;
  logic [15:0] seen_down_left;
  logic [15:0] seen_down_right;
  logic [15:0] seen_up_left;
  logic [15:0] seen_up_right;

  synth_forwarded_parameterized_interface_array_netlist dut(.*);

  (* ivl_synthesis_off *)
  initial begin
    down_left = 16'ha3a3;
    down_right = 16'ha2a2;
    up_left = 16'hb3b3;
    up_right = 16'hb2b2;
    #1;
    if ({seen_down_left, seen_down_right, seen_up_left, seen_up_right} !==
        {down_left, down_right, up_left, up_right})
      $fatal(1, "FAILED down=%h/%h up=%h/%h",
             seen_down_left, seen_down_right,
             seen_up_left, seen_up_right);
    $display("PASSED forwarded down=%h/%h up=%h/%h",
             seen_down_left, seen_down_right,
             seen_up_left, seen_up_right);
  end
endmodule
