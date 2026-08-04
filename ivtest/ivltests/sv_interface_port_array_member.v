interface LANE_IF #(
  parameter Width = 8
);
  logic [Width-1:0] command;
  logic [Width-1:0] result;

  modport Router_Ports(input result, output command);
  modport Device_Ports(input command, output result);
endinterface

module lane_router #(
  parameter Count = 2
) (
  LANE_IF.Router_Ports lanes [0:Count-1],
  input  logic [Count-1:0][7:0] commands,
  output logic [Count-1:0][7:0] results
);
  for (genvar lane = 0; lane < Count; lane++) begin : gen_lanes
    assign lanes[lane].command = commands[lane];
    assign results[lane] = lanes[lane].result;
  end
endmodule

module lane_transform(
  input  logic [7:0] command_i,
  output logic [7:0] result_o
);
  assign result_o = command_i + 8'd1;
endmodule

module lane_device(LANE_IF.Device_Ports lane);
  // Exercise ordinary scalar module ports whose actuals are interface
  // members in both directions, as used by Caliptra's AHB decoder.
  lane_transform transform(
    .command_i(lane.command),
    .result_o(lane.result)
  );
endmodule

module main;
  logic [1:0][7:0] commands;
  logic [1:0][7:0] results;
  LANE_IF lanes [0:1] ();

  lane_router router(
    .lanes(lanes),
    .commands(commands),
    .results(results)
  );
  lane_device device0(lanes[0]);
  lane_device device1(lanes[1]);

  initial begin
    commands[0] = 8'h20;
    commands[1] = 8'h7e;
    #1;
    if (results[0] !== 8'h21 || results[1] !== 8'h7f)
      $display("FAILED -- results=%h,%h", results[0], results[1]);
    else
      $display("PASSED");
    $finish;
  end
endmodule
