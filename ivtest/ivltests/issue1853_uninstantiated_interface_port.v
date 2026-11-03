interface issue1853_mem_if;
  logic req;
  modport resp(input req);
endinterface

module issue1853_orphan(issue1853_mem_if.resp bus);
  logic unused;
  assign unused = bus.req;
endmodule

module issue1853_tb;
  initial begin
    #1;
    $display("DONE");
    $finish;
  end
endmodule
