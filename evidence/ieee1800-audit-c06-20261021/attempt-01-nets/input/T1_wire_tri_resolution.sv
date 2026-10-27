module top;
  logic a, b;
  wire first; tri second;
  assign first = a;
  assign first = b;
  assign second = a;
  assign second = b;
  integer i, j;
  initial begin
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        case (i)
          0: a = 1'b0;
          1: a = 1'b1;
          2: a = 1'bx;
          3: a = 1'bz;
        endcase
        case (j)
          0: b = 1'b0;
          1: b = 1'b1;
          2: b = 1'bx;
          3: b = 1'bz;
        endcase
        #1 $display("%0d%0d %b %b", i, j, first, second);
      end
    end
  end
endmodule
