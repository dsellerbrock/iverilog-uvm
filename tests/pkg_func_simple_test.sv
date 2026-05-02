package mypkg;
   bit pkg_called;
   function automatic void touch();
      pkg_called = 1;
   endfunction
endpackage

module top;
   initial begin
      mypkg::touch();
      $display("pkg_called=%0d", mypkg::pkg_called);
      if (mypkg::pkg_called) $display("PKG SIMPLE: PASS");
      else $display("PKG SIMPLE: FAIL");
      $finish;
   end
endmodule
