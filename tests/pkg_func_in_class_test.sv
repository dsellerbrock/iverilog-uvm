// Test: a class method calls a package function with the SAME NAME as a
// virtual method on the class. The package call should go to the
// package function, not recurse back into the class.
package mypkg;
   bit pkg_called;
   function automatic void touch();
      pkg_called = 1;
   endfunction
endpackage

class base;
   int counter;
   virtual function void touch();
      counter += 1;
      mypkg::touch();    // Should call pkg's touch, NOT recurse
   endfunction
endclass

class derived extends base;
endclass

module top;
   import mypkg::*;
   derived d;
   initial begin
      d = new();
      d.touch();
      $display("counter=%0d pkg_called=%0d", d.counter, mypkg::pkg_called);
      if (d.counter == 1 && mypkg::pkg_called == 1)
         $display("PKG FUNC IN CLASS: PASS");
      else
         $display("PKG FUNC IN CLASS: FAIL");
      $finish;
   end
endmodule
