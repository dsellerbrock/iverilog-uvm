/*
 * Verify that associative-array object lookups remain class-typed when
 * used in a ternary with null.
 */

class ext;
   int id;

   function new(int value);
      id = value;
   endfunction
endclass

class holder;
   ext m_extensions[ext];

   function ext get(ext lookup);
      ext rhs;
      rhs = m_extensions.exists(lookup) ? m_extensions[lookup] : null;
      return rhs;
   endfunction
endclass

module main;

   initial begin
      holder h;
      ext key_h;
      ext miss_h;
      ext value_h;
      ext got_h;

      h = new;
      key_h = new(7);
      miss_h = new(11);
      value_h = new(99);

      h.m_extensions[key_h] = value_h;

      got_h = h.get(key_h);
      if (got_h == null || got_h.id != 99) begin
         $display("FAILED -- existing key lookup broken");
         $finish;
      end

      got_h = h.get(miss_h);
      if (got_h != null) begin
         $display("FAILED -- missing key should return null");
         $finish;
      end

      $display("PASSED");
      $finish;
   end

endmodule
