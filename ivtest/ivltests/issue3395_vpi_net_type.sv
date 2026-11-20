module net_type_port(inout trireg cap);
endmodule

module top;
   supply0 s0;
   supply1 s1;
   tri t = 1'b0;
   tri0 t0;
   tri1 t1;
   tri1 #1 delayed_pull;
   trireg held = 1'b1;
   triand ta = 1'b0;
   trior to = 1'b1;
   wand wa = 1'b0;
   wor wo = 1'b1;
   uwire uw = 1'b0;
   triand [3:2] words [2:3];
   wor [3:2] vector_net = 2'b10;
   wand [1:0][3:2] packed_net = 4'b1010;

   assign words[2] = 2'b10;
   assign words[3] = 2'b01;

   // The port and its actual share charge but retain distinct declarations.
   wire ordinary;
   reg enable = 1;
   bufif1 (ordinary, 1'b1, enable);
   net_type_port u(ordinary);

   initial begin
      $dumpfile("issue3395_vpi_net_type.vcd");
      $dumpvars(0, top);
      #2;
      if (delayed_pull !== 1'b1 || {ordinary, u.cap} !== 2'b11)
         $fatal(1, "wrong value on delayed pull or collapsed port");
      enable = 0;
      #1;
      if ($sformatf("%v", ordinary) != "Me1" || $sformatf("%v", u.cap) != "Me1")
         $fatal(1, "collapsed port did not share stored charge");
      $dumpflush;
      $issue3395_check;
   end
endmodule
