module issue2409_class_property_display;
  class C;
    logic [64:0] a;
    logic [129:0] w;
  endclass

  C o[3];
  C s;

  initial begin
    o[0] = new;
    s = new;
    $display("arr %h | %o | %h", o[0].a, o[0].a, o[0].w);
    $display("one %h | %o | %h", s.a, s.a, s.w);
  end
endmodule
