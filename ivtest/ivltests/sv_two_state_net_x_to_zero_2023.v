// A 2-state variable written through a continuous assignment holds X and Z
// as 0, and its readers see 0 too (IEEE 1800-2017/2023 6.8, 10.10). A `bit'
// that was one part of a mixed `{logic, bit} = ...' target kept X in its
// fanout, so `~kv' stayed X (OpenTitan ibex_icache: the scramble-key handshake
// dropped `req' before `ack').
module main;
  int errors;
  logic [3:0] dd = 4'bxxxx;
  logic [1:0] lg, lg2;
  bit kv;
  bit [1:0] pk;
  assign {lg, kv} = dd[2:0];
  assign {lg2, pk} = dd;
  wire inv = ~kv;
  wire [1:0] ninv = ~pk;
  logic q = 1;
  wire rq = q ? ~kv : 1'b0;
  initial begin
    #1;
    if (kv !== 1'b0) begin $display("FAILED kv=%b", kv); errors++; end
    if (pk !== 2'b00) begin $display("FAILED pk=%b", pk); errors++; end
    if (inv !== 1'b1) begin $display("FAILED inv=%b", inv); errors++; end
    if (ninv !== 2'b11) begin $display("FAILED ninv=%b", ninv); errors++; end
    if (rq !== 1'b1) begin $display("FAILED rq=%b", rq); errors++; end
    if (lg !== 2'bxx || lg2 !== 2'bxx) begin $display("FAILED 4-state part lg=%b lg2=%b", lg, lg2); errors++; end
    dd = 4'b1011;
    #1;
    if (kv !== 1'b1 || pk !== 2'b11 || inv !== 1'b0) begin
      $display("FAILED known kv=%b pk=%b inv=%b", kv, pk, inv); errors++;
    end
    dd = 4'bz1zz;
    #1;
    if (kv !== 1'b0 || pk !== 2'b00) begin $display("FAILED z kv=%b pk=%b", kv, pk); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
