module top;
   bit pass;

   int q [$];

   initial begin
      int x;
      int c;
      int hits;
      int i;

      pass = 1;

      x = 5;
      if (!(x inside {[0:10]}))   begin $display("FAIL: 5 not inside [0:10]"); pass = 0; end
      if   (x inside {[100:200]}) begin $display("FAIL: 5 inside [100:200]"); pass = 0; end

      x = 42;
      if (!(x inside {1, 42, 99})) begin $display("FAIL: 42 not in scalars"); pass = 0; end
      if   (x inside {1, 2, 3})    begin $display("FAIL: 42 in {1,2,3}"); pass = 0; end

      q.push_back(65);
      q.push_back(66);
      q.push_back(67);

      hits = 0;
      i = 0;
      c = 65;
      while (c inside {q}) begin
         hits = hits + 1;
         i = i + 1;
         if (i > 10) begin pass = 0; break; end
         if (i < 3) c = q[i];
         else       c = 0;
      end
      if (hits != 3) begin
         $display("FAIL: hits=%0d (expected 3)", hits);
         pass = 0;
      end

      x = 999;
      if (x inside {q}) begin $display("FAIL: 999 in q"); pass = 0; end

      if (pass) $display("inside runtime PASSED!");
      else      $display("inside runtime FAILED");
      $finish;
   end
endmodule
