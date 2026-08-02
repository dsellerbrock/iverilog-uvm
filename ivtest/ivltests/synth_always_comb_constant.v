`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic [2:0] mode;
    logic enable;
  } attr_t;

  attr_t attr;

  always_comb begin
    attr = '0;
    attr.mode = 3'b101;
    attr.enable = 1'b1;
  end

  (* ivl_synthesis_off *)
  initial begin
    #1;
    if (attr !== 4'b1011) begin
      $display("FAILED -- constant always_comb value=%b", attr);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
