// weak_reference is new in IEEE 1800-2023 (8.30). Under 1800-2017 the name
// is an ordinary identifier; in 1800-2023 a user declaration still wins.
module top;
   int weak_reference;
   class holder;
      int weak_reference = 3;
   endclass
   holder h = new;
   initial begin
      weak_reference = 4;
      if (weak_reference + h.weak_reference == 7)
	 $display("PASSED");
      else
	 $display("FAILED");
   end
endmodule
