// IEEE 1800-2023 32.4.4: an INTERCONNECT source may be an output or inout
// port and a load an input or inout port. The delay applies from the
// source to the load only; the other side of an inout boundary is not
// delayed by it.
`timescale 1ns/1ns
module src(input a, output y); assign y = a; endmodule
module bidi_src(input drive, input v, inout y); assign y = drive ? v : 1'bz; endmodule
module bidi_dst(inout a, input en, output y); assign y = a; assign a = en ? 1'b0 : 1'bz; endmodule
module sink(input a, output y); assign y = a; endmodule

module issue1572_inout_interconnect;
  reg a = 0, en = 0, drive = 1, v = 0;
  tri link1, link2;
  wire y1, y2;
  reg fail = 0;

  src      u1(a, link1);     // output source
  bidi_dst u2(link1, en, y1); // inout load
  bidi_src u3(drive, v, link2); // inout source
  sink     u4(link2, y2);    // input load

  task check(input got, input exp, input [8*8-1:0] what);
    if (got !== exp) begin
      $display("FAILED: t=%0t %0s=%b, expected %b", $time, what, got, exp);
      fail = 1;
    end
  endtask

  initial begin
    $sdf_annotate("ivltests/issue1572_inout_interconnect.sdf", issue1572_inout_interconnect);
    #10 a = 1;
    #1 check(link1, 1'b1, "link1");  // the source side is not delayed
       check(y1, 1'b0, "y1");        // the load still sees the old value
    #3 check(y1, 1'b1, "y1");        // 3 after the change
    #6 en = 1;                       // the load drives 0 against the source's 1
    #1 check(link1, 1'bx, "link1");  // load -> source is not annotated
       check(y1, 1'bx, "y1");
    #9 v = 1;
    #3 check(y2, 1'b0, "y2");
    #2 check(y2, 1'b1, "y2");        // 4 after the change
    if (!fail) $display("PASSED");
    $finish;
  end
endmodule
