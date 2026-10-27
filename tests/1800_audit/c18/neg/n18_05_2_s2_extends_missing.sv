class B; rand bit [3:0] v; constraint c1 { v < 8; } endclass
class D extends B; constraint :extends cz { v > 1; } endclass
module p18_05_2_s2; endmodule
