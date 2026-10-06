`begin_keywords "1800-2012"

module main;
  logic clk;
  logic [2:0] state;
  logic cond_a, cond_b;
  logic [7:0] result;

  (* ivl_synthesis_off *)
  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    case (state)
      3'd0: begin
        if (cond_a) result <= 8'h03;
        else        result <= 8'h05;
      end
      3'd2: begin
        if (cond_b) result <= 8'h18;
        else        result <= 8'h28;
      end
      3'd3: begin
        if (cond_a && cond_b) result <= 8'h40;
        else                  result <= 8'h42;
      end
      default: result <= 8'h80;
    endcase
  end

  task automatic check(input logic [2:0] sel,
                       input logic a, b,
                       input logic [7:0] expected);
    @(negedge clk);
    state = sel;
    cond_a = a;
    cond_b = b;
    @(posedge clk);
    #1;
    if (result !== expected) begin
      $display("FAILED -- state=%0d a=%b b=%b got=%h expected=%h",
               sel, a, b, result, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 0;
    state = 0;
    cond_a = 0;
    cond_b = 0;
    check(3'd0, 1, 0, 8'h03);
    check(3'd0, 0, 0, 8'h05);
    check(3'd2, 0, 1, 8'h18);
    check(3'd2, 0, 0, 8'h28);
    check(3'd3, 1, 1, 8'h40);
    check(3'd3, 1, 0, 8'h42);
    check(3'd1, 0, 0, 8'h80);
    check(3'd7, 1, 1, 8'h80);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
