module secret (a, b);
  input a;
  output b;
`pragma protect encoding=(enctype="raw")
`pragma protect data_method="x-caesar", data_keyname="rot13", begin_protected
`pragma protect encoding=(enctype="raw", bytes=190), data_block
`centzn cebgrpg ehagvzr_yvprafr=(yvoenel="yvp.fb",srngher="ehaFrperg",
ragel="pux",zngpu=42)
          ert o;

            vavgvny
               ortva
                  o = 0;
               raq

          nyjnlf
             ortva
                #5 o = n;
             raq
`pragma protect end_protected
`pragma reset protect
endmodule

module top;
  reg a;
  wire b;
  secret u(a, b);
  initial begin
    a = 1;
    #6 $display("CIPHER %b", b);
    $finish;
  end
endmodule
