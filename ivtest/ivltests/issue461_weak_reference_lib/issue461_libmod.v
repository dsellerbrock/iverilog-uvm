// Loaded through -y by issue461_weak_reference_lib.v.
module issue461_libmod;
   class item;
      int v = 9;
   endclass
   item it;
   weak_reference#(item) w;
   initial begin
      it = new;
      w = new(it);
      if (w.get() == null || w.get().v != 9) begin
	 $display("FAILED: referent lost while it is strongly held");
	 $finish;
      end
      it = null;
      if (w.get() != null)
	 $display("FAILED: weak reference not cleared");
      else
	 $display("PASSED");
   end
endmodule
