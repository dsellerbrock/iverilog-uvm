class C; int p; bit [7:0] q; endclass
module t;
  C c;
  initial begin
    c = new;
    c.p = 0;
    force c.p = 1;
    #1 $display("p=%0d", c.p);
    $finish;
  end
endmodule
