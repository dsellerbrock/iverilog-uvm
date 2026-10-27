package p1;
  int x = 5;
endpackage

package p2;
  import p1::x;
  export p1::*;
endpackage

package p3;
  import p2::x;
  export p2::*;
  int q = 5;
endpackage

module issue952_chained_package_export;
  import p3::*;

  initial begin
    $display("x=%0d q=%0d", x, q);
  end
endmodule
