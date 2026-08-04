`begin_keywords "1800-2012"

module scalar_data_select (
  input  logic       clk,
  input  logic [3:0] data,
  output logic       state
);
  always_ff @(posedge clk)
    state <= data[2];
endmodule

module scalar_output_select (
  input  logic       clk,
  input  logic       data,
  output logic [3:0] state
);
  always_ff @(posedge clk)
    state[1] <= data;
endmodule

module main;
  logic       clk;
  logic [3:0] data;
  logic       selected_data_state;
  logic [3:0] selected_output_state;

  scalar_data_select data_select (
    .clk, .data, .state(selected_data_state)
  );
  scalar_output_select output_select (
    .clk, .data(data[0]), .state(selected_output_state)
  );

  task tick;
    begin
      #1 clk = 1'b1;
      #1 clk = 1'b0;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    data = 4'b0101;
    tick();
    if (selected_data_state !== 1'b1 ||
	selected_output_state !== 4'bxx1x) begin
      $display("FAILED -- first selected values were %b/%b",
               selected_data_state, selected_output_state[1]);
      $finish;
    end

    data = 4'b0000;
    tick();
    if (selected_data_state !== 1'b0 ||
	selected_output_state !== 4'bxx0x) begin
      $display("FAILED -- second selected values were %b/%b",
               selected_data_state, selected_output_state[1]);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
