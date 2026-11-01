module event_port(input event e);
  initial begin
    @e $display("CHILD");
  end
  initial begin
    #2 -> e;
  end
endmodule

module tb;
  event e;
  event_port u(e);

  initial begin
    #1 -> e;
  end
  initial begin
    @e $display("PARENT");
  end
endmodule
