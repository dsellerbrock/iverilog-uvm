module top;
  logic a, b;
  tri0 first;
  tri1 second;
  tri0 undriven0;
  tri1 undriven1;
  assign first = a;
  assign first = b;
  assign second = a;
  assign second = b;
  integer i, j;
  initial begin
    $display("undriven %v %v", undriven0, undriven1);
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
        #1 $display("%0d%0d %b %b %v %v", i, j, first, second, first, second);
      end
    end
  end
endmodule
