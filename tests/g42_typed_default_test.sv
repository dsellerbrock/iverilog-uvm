// G42: typed-default in assignment pattern '{int: 0, default: 8'hFF}
// Tests type-key selectors: int members get typed value, others get default
module g42_typed_default_test;
  typedef struct packed {
    int x;
    byte y;
  } my_s;

  my_s s;

  initial begin
    // int: 0 applies to x (int), default: 8'hFF applies to y (byte)
    s = '{int: 0, default: 8'hFF};
    if (s.x === 32'h0 && s.y === 8'hFF) begin
      $display("PASS: x=%0h y=%0h", s.x, s.y);
    end else begin
      $display("FAIL: x=%0h y=%0h (expected x=0 y=FF)", s.x, s.y);
      $finish(1);
    end
  end
endmodule
