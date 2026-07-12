// M3 signed-constraint regression (IEEE 1800-2017 11.8.1; Ch.18).
module m3_constraint_signed_test;
  class SC;
    rand int x;                       // signed
    rand int y;
    constraint c { x inside {[-5:5]}; y < 0; y >= -20; }
  endclass
  initial begin
    SC s = new;
    int errors = 0;
    repeat (20) begin
      void'(s.randomize());
      if (!(s.x >= -5 && s.x <= 5)) begin
        $display("FAIL x=%0d", s.x); errors++;
      end
      if (!(s.y < 0 && s.y >= -20)) begin
        $display("FAIL y=%0d", s.y); errors++;
      end
    end
    if (errors == 0) $display("PASS");
  end
endmodule
