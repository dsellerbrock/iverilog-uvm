class C; int p; bit [7:0] q; endclass
module t;
  C c;
  initial begin
    c = new;
    c.q = 0;
    assign c.q[0] = 1'b1;
    #1 $display("q=%02h", c.q);
    deassign c.q[0];
    $finish;
  end
endmodule
