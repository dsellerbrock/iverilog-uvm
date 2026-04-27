module top;
   typedef enum int { RED=0, GREEN=1, BLUE=2 } color_t;
   color_t c;

   bit pass;

   initial begin
      pass = 1;
      c = GREEN;
      if (c.name()  != "GREEN") begin $display("FAIL: c.name=%s", c.name()); pass=0; end
      if (c.next()  != BLUE)    begin $display("FAIL: c.next=%0d", c.next()); pass=0; end
      if (c.prev()  != RED)     begin $display("FAIL: c.prev=%0d", c.prev()); pass=0; end
      if (c.first() != RED)     begin $display("FAIL: c.first=%0d", c.first()); pass=0; end
      if (c.last()  != BLUE)    begin $display("FAIL: c.last=%0d", c.last()); pass=0; end
      if (c.num()   != 3)       begin $display("FAIL: c.num=%0d", c.num()); pass=0; end
      if (pass) $display("ENUM METHOD TEST: PASS");
      else      $display("ENUM METHOD TEST: FAIL");
      $finish;
   end
endmodule
