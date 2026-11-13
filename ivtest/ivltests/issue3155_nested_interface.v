module issue3155_nested_interface;
  interface bus;
    int n = 0;
    modport h(ref n);
  endinterface
  module cpu(bus.h b);
    initial begin
      #1;
      if (b.n !== 0) $fatal(1, "wrong initial value: %0d", b.n);
      b.n = 17;
    end
  endmodule
  bus b1();
  cpu c(b1.h);
  initial begin
    #2;
    if (b1.n !== 17) $fatal(1, "wrong updated value: %0d", b1.n);
    $display("PASS");
  end
endmodule
