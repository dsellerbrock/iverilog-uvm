`timescale 1ns/1ps
module pulsebuf_showcancelled(input a, output y);
  buf (y,a);
  specify
    showcancelled y;
    (a => y)=(6,4);
  endspecify
endmodule

module pulsebuf_default(input a, output y);
  buf (y,a);
  specify
    (a => y)=(6,4);
  endspecify
endmodule

module issue1241_showcancelled_negative_pulse_2017;
  reg a=0;
  wire show_y, default_y;
  pulsebuf_showcancelled show_buf(a, show_y);
  pulsebuf_default default_buf(a, default_y);
  initial begin
    $monitor("t=%0t a=%b show=%b default=%b", $time, a, show_y, default_y);
    #10 a=1; #1 a=0; #10 $finish;
  end
endmodule
