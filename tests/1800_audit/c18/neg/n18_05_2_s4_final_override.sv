class B; rand bit [3:0] v; constraint :final c1 { v < 8; } endclass
class D extends B; constraint c1 { v > 1; } endclass
module p18_05_2_s4; endmodule
