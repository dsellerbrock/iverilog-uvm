interface responder_if;
  logic [31:0] haddr;
  logic [63:0] hrdata;
  logic hready, hreadyout, hresp, hsel;
  logic [2:0] hsize;
  logic [1:0] htrans;
  logic [63:0] hwdata;
  logic hwrite;
  modport responder(output haddr, hready, hsel, hsize, htrans, hwdata, hwrite,
                    input hrdata, hreadyout, hresp);
endinterface

module array17_bus(responder_if.responder responders[0:16],
                   input logic [16:0][31:0] addresses,
                   output logic [16:0][63:0] read_data);
  for (genvar i = 0; i < 17; i++) begin: hook
    assign responders[i].haddr = addresses[i];
    assign responders[i].hwdata = 64'(i);
    assign responders[i].hsel = 1'b1;
    assign responders[i].hwrite = 1'b0;
    assign responders[i].hready = 1'b1;
    assign responders[i].htrans = 2'b10;
    assign responders[i].hsize = 3'b011;
    assign read_data[i] = responders[i].hrdata;
  end
endmodule

module array17_safe;
  logic [16:0][31:0] addresses;
  logic [16:0][63:0] read_data;
  responder_if ports[0:16]();
  array17_bus bus(.responders(ports), .addresses(addresses),
                  .read_data(read_data));
  for (genvar i = 0; i < 17; i++) begin: drive
    assign ports[i].hrdata = 64'(i + 1);
  end
  initial begin
    for (int i = 0; i < 17; i++) addresses[i] = i + 100;
    #1;
    for (int i = 0; i < 17; i++)
      if (read_data[i] !== 64'(i + 1))
        $fatal(1, "responder word %0d mismatch", i);
    if (ports[0].haddr !== 32'd100 || ports[16].haddr !== 32'd116)
      $fatal(1, "responder address mismatch");
    $display("PASSED array17 interface port and member waits");
  end
endmodule
