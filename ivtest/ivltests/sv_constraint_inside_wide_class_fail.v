class C; rand bit [7:0] a,b; bit [127:0] q[$]; constraint c { a==250; b==10; int'(((a+b)/8'd2) inside {q, 8'd2}) == 1; } endclass
module test; C c=new; initial begin if(!c.randomize()) $fatal(1,"false narrow result rejected"); $display("ACCEPTED_NARROW");end endmodule
