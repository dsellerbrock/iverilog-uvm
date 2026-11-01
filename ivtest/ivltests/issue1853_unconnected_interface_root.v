interface mem_if;
  logic req;
  modport resp(input req);
endinterface

module orphan(mem_if.resp bus);
  logic unused;
  assign unused = bus.req;
endmodule

module tb;
  initial begin
    #1;
    $display("DONE");
    $finish;
  end
endmodule
