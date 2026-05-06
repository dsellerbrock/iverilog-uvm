// G13: packed-struct '{default: V} should fill all members
module g13_packed_struct_default_test;
  typedef struct packed {
    logic [3:0] a;
    logic [3:0] b;
  } my_s;

  my_s s;

  initial begin
    s = '{default: 4'hF};
    if (s.a === 4'hF && s.b === 4'hF) begin
      $display("PASS: s.a=%0h s.b=%0h", s.a, s.b);
    end else begin
      $display("FAIL: s.a=%0h s.b=%0h (expected F F)", s.a, s.b);
      $finish(1);
    end
  end
endmodule
