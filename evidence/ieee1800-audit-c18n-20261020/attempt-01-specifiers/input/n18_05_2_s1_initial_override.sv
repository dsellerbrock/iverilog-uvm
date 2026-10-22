class B; rand bit [3:0] v; constraint c1 { v < 8; } endclass
class D extends B; constraint :initial c1 { v > 1; } endclass
module p18_05_2_s1; endmodule
