// Reproduce the str_strip loop pattern from OpenTitan str_utils_pkg.
// Before the inside-operator fix, `inside { chars_q }` always returned
// constant true, so the while-loop became infinite and the runtime
// hotspot detector forced a return after 200000 iterations.
module top;
   bit pass;

   initial begin
      string s;
      string chars;
      byte chars_q [$];
      int i;
      string out;

      pass = 1;
      s = "  hello  ";
      chars = " \t\n";

      // Build chars_q from the chars string — exact str_strip pattern.
      foreach (chars[k]) chars_q.push_back(chars.getc(k));

      // Left-strip
      i = 0;
      while (s.getc(i) inside {chars_q}) i++;
      out = s.substr(i, s.len() - 1);
      // Right-strip
      i = out.len() - 1;
      while (out.getc(i) inside {chars_q}) i--;
      out = out.substr(0, i);

      if (out != "hello") begin
         $display("FAIL: stripped='%s' (expected 'hello')", out);
         pass = 0;
      end

      // Test: chars_q empty -> nothing should match -> no iteration
      while (chars_q.size() > 0) chars_q.pop_back();
      i = 0;
      // This loop must NOT iterate (chars_q is empty)
      while (s.getc(i) inside {chars_q}) begin
         i++;
         if (i > 100) begin pass = 0; $display("FAIL: empty chars_q infinite loop"); break; end
      end
      if (i != 0) begin $display("FAIL: empty-q loop ran (i=%0d)", i); pass = 0; end

      if (pass) $display("STR_STRIP PATTERN: PASS");
      else      $display("STR_STRIP PATTERN: FAIL");
      $finish;
   end
endmodule
