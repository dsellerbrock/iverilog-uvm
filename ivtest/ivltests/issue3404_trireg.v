`timescale 100ps/100ps
module issue3404_port(cap, sense);
   inout cap;
   input sense;
   trireg (large) #(0, 0, 15) cap;
endmodule

`timescale 1ns/1ns
module issue3404_trireg;
   reg d, en;
   trireg (small) #(0, 0, 10) finite_charge;
   trireg [3:2] #(2, 3) held_charge;
   trireg (large) #(0, 0, 0) zero_decay;
   tri0 overridden_charge;
   wire port_charge, sense_wire;

   bufif1 (finite_charge, d, en);
   bufif1 held_driver[3:2] (held_charge, d, en);
   bufif1 (zero_decay, d, en);
   bufif1 (port_charge, d, en);
   buf (sense_wire, d);
   // The external tri0 dominates one instance. The other keeps the
   // internal trireg and its delay in the child timescale.
   issue3404_port u_external(overridden_charge, sense_wire);
   issue3404_port u_internal(port_charge, finite_charge);

   initial begin
      d = 1;
      en = 1;
      #1 $display("rise pending: %b", held_charge);
      #2 $display("driven: %v %b %v %v", finite_charge, held_charge,
                 zero_decay, port_charge);
      d = 0;
      #2 $display("fall pending: %b", held_charge);
      #2 $display("fallen: %b", held_charge);
      d = 1;
      #3 en = 0;
      #1 $display("released: %v %v %v %v %v", finite_charge, zero_decay,
                 port_charge, u_internal.sense, overridden_charge);
      #1 $display("port decayed: %v", port_charge);
      #7 $display("before decay: %v", finite_charge);
      #2 $display("after decay: %v %v", finite_charge, held_charge[3]);
   end
endmodule
