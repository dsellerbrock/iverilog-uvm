interface parameterized_array_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] down;
  logic [WIDTH-1:0] up;

  modport router(
    output down,
    input up
  );
endinterface

module parameterized_array_router(
  parameterized_array_if.router ports [0:1],
  input  logic [15:0] down0,
  input  logic [15:0] down1,
  output logic [15:0] seen_up0,
  output logic [15:0] seen_up1
);
  logic [15:0] down_data [0:1];
  logic [15:0] up_data [0:1];

  assign down_data[0] = down0;
  assign down_data[1] = down1;
  assign seen_up0 = up_data[0];
  assign seen_up1 = up_data[1];

  // The two different payloads prove both the member width and the mapping
  // from each ascending formal-array word to its matching interface instance.
  for (genvar i = 0; i < 2; i++) begin : g_route
    assign ports[i].down = down_data[i];
    assign up_data[i] = ports[i].up;
  end
endmodule

module synth_parameterized_interface_member_array_netlist(
  input  logic [15:0] down0,
  input  logic [15:0] down1,
  input  logic [15:0] up0,
  input  logic [15:0] up1,
  output logic [15:0] seen_down0,
  output logic [15:0] seen_down1,
  output logic [15:0] seen_up0,
  output logic [15:0] seen_up1
);
  parameterized_array_if #(.WIDTH(16)) bus [0:1] ();

  assign bus[0].up = up0;
  assign bus[1].up = up1;
  parameterized_array_router router(.ports(bus), .*);
  assign seen_down0 = bus[0].down;
  assign seen_down1 = bus[1].down;
endmodule

module synth_parameterized_interface_member_array;
  logic [15:0] down0;
  logic [15:0] down1;
  logic [15:0] up0;
  logic [15:0] up1;
  logic [15:0] seen_down0;
  logic [15:0] seen_down1;
  logic [15:0] seen_up0;
  logic [15:0] seen_up1;

  synth_parameterized_interface_member_array_netlist dut(.*);

  (* ivl_synthesis_off *)
  initial begin
    down0 = 16'habcd;
    down1 = 16'h12ef;
    up0 = 16'hcafe;
    up1 = 16'h34dc;
    #1;
    if ({seen_down0, seen_down1, seen_up0, seen_up1} !==
        {down0, down1, up0, up1})
      $fatal(1, "FAILED down=%h/%h up=%h/%h",
             seen_down0, seen_down1, seen_up0, seen_up1);
    $display("PASSED down=%h/%h up=%h/%h",
             seen_down0, seen_down1, seen_up0, seen_up1);
  end
endmodule
