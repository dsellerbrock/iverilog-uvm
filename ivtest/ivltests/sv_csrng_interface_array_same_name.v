// IEEE 1800-2017/2023 3.13, 28.3.5: the interface type and its local
// instance array may have the same spelling; a genvar selects each member.
package csrng_same_name_pkg;
  typedef struct packed {
    logic valid;
    logic [3:0] data;
  } req_t;
endpackage

interface csrng_same_name_if;
  import csrng_same_name_pkg::*;
  wire req_t cmd_req = 5'b10101;
  wire req_t cmd_rsp;
endinterface

module sv_csrng_interface_array_same_name;
  import csrng_same_name_pkg::*;
  req_t [1:0] observed;
  req_t [1:0] response;
  csrng_same_name_if csrng_same_name_if[2]();

  for (genvar i = 0; i < 2; i++) begin : g
    assign observed[i] = csrng_same_name_if[i].cmd_req;
    assign csrng_same_name_if[i].cmd_rsp = response[i];
  end

  initial begin
    response[0] = 5'b10001;
    response[1] = 5'b01110;
    #1;
    if (observed !== {5'b10101, 5'b10101} ||
        csrng_same_name_if[0].cmd_rsp !== 5'b10001 ||
        csrng_same_name_if[1].cmd_rsp !== 5'b01110)
      $fatal(1, "indexed interface instance did not preserve member values");
    $display("PASSED");
    $finish(0);
  end
endmodule
