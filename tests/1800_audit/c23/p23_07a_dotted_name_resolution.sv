typedef struct packed { logic [3:0] x; } payload_t;

module leaf;
  logic [3:0] value;
endmodule

module top;
  payload_t payload;
  leaf u();
  initial begin
    payload.x = 4'ha;
    u.value = 4'h5;
    #1;
    if (payload.x !== 4'ha || u.value !== 4'h5)
      $fatal(1, "dotted name resolution failed");
    $display("PASS: dotted name resolution");
  end
endmodule
