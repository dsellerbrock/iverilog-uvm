class C; int p; bit [7:0] q; endclass
module t;
  C c;
  initial begin
    c = new;
    c.q = 0;
    force c.q[0] = 1'b1;
    #1 $display("q=%02h", c.q);
    $finish;
  end
endmodule
