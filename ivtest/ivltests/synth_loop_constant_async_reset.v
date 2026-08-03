`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    integer selected_index;
  } target_cfg_t;

  typedef struct packed {
    logic       pull_en;
    logic [1:0] padding;
  } pad_attr_t;

  localparam int Width = 4;
  localparam target_cfg_t TargetCfg = '{selected_index: 2};

  logic             clk;
  logic             reset_n;
  logic [Width-1:0] enable;
  pad_attr_t [Width-1:0] data;
  pad_attr_t [Width-1:0] state;

  // OpenTitan pinmux reset values depend on a packed-struct parameter and
  // the constant value of an unrolled procedural-loop index. Each iteration
  // must select one reset branch at synthesis time; retaining a run-time mux
  // incorrectly turns the constant reset vector into an asynchronous load.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      for (int index = 0; index < Width; index++) begin
        if (index == TargetCfg.selected_index)
          state[index] <= '{pull_en: 1'b1, default: '0};
        else
          state[index] <= '0;
      end
    end else begin
      for (int index = 0; index < Width; index++) begin
        if (enable[index])
          state[index] <= data[index];
      end
    end
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic check(input string label,
                       input logic [2:0] expected0,
                       input logic [2:0] expected1,
                       input logic [2:0] expected2,
                       input logic [2:0] expected3);
    if (state[0] !== expected0 || state[1] !== expected1 ||
        state[2] !== expected2 || state[3] !== expected3) begin
      $display("FAILED -- %s state=%b/%b/%b/%b expected=%b/%b/%b/%b",
               label, state[0], state[1], state[2], state[3],
               expected0, expected1, expected2, expected3);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    reset_n = 1'b1;
    enable = '0;
    data = '0;

    #1 reset_n = 1'b0;
    #1;
    check("parameter-selected asynchronous reset",
          3'b000, 3'b000, 3'b100, 3'b000);

    reset_n = 1'b1;
    enable = 4'b1010;
    data[0] = '{pull_en: 1'b0, padding: 2'b01};
    data[1] = '{pull_en: 1'b1, padding: 2'b10};
    data[2] = '{pull_en: 1'b0, padding: 2'b11};
    data[3] = '{pull_en: 1'b1, padding: 2'b01};
    tick();
    check("enabled updates", 3'b000, 3'b110, 3'b100, 3'b101);

    enable = 4'b0101;
    tick();
    check("disjoint enabled updates", 3'b001, 3'b110, 3'b011, 3'b101);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
