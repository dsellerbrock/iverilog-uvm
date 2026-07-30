
/*
 * This tests a trivial class. This tests that properties can be
 * given types, and that the types behave properly.
 */
program main;

   // Trivial example of a class
   class foo_t ;
      byte a;
      int b[];
   endclass : foo_t // foo_t

   foo_t obj;
   int	 tmp[];

   initial begin
      obj = new;

      // This is the most trivial assignment of class properties.
      obj.a = 'hf_ff;
      obj.b = new[2];

      // Write the property elements directly. (This test used to write
      // through `tmp' after `tmp = obj.b' and expect the writes to show
      // up in obj.b -- but IEEE 1800-2017 7.6 says dynamic-array
      // assignment COPIES the elements, so tmp is an independent array.)
      obj.b[0] = 0;
      obj.b[1] = 1;

      if (obj.a != -1) begin
	 $display("FAILED -- assign to object: obj.a=%0d", obj.a);
	 $finish;
      end

      tmp = obj.b;

      if (tmp.size() != 2) begin
	 $display("FAILED -- obj.b.size() = %0d", tmp.size());
	 $finish;
      end
      if (tmp[0] != 0 || tmp[1] != 1) begin
	 $display("FAILED -- obj.b[0]=%0d, obj.b[1]=%0d", tmp[0], tmp[1]);
	 $finish;
      end

      // And the copy really is a copy: mutating it must not write
      // through to the property (IEEE 1800-2017 7.6).
      tmp[0] = 42;
      if (obj.b[0] != 0) begin
	 $display("FAILED -- copy aliased the property: obj.b[0]=%0d", obj.b[0]);
	 $finish;
      end

      $display("PASSED");
      $finish;
   end
endprogram // main
