module p10_03a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  logic [3:0] ina = 4'd9, inb = 4'd9;  logic carry_in = 1;  wire [3:0] sum_out;  wire carry_out;
  assign {carry_out, sum_out} = ina + inb + carry_in;
  logic en = 1;  wire (strong1, pull0) mynet = en;
  logic [1:2] s = 2;  logic [1:4] bus0 = 4'h1, bus1 = 4'h2, bus2 = 4'h4, bus3 = 4'h8;
  parameter [1:4] Zee = 4'bz;
  tri [1:4] data;  tri [1:4] busout = en ? data : Zee;
  assign data = (s == 0) ? bus0 : Zee, data = (s == 1) ? bus1 : Zee, data = (s == 2) ? bus2 : Zee, data = (s == 3) ? bus3 : Zee;
  logic vv;  assign vv = en;
  wire sw;   assign (pull1, pull0) sw = 1'b0;  assign (weak1, weak0) sw = 1'b1;
  wire sw2;  assign sw2 = 1'b0;  assign (weak1, weak0) sw2 = 1'b1;
  wire sw3;  assign sw3 = 1'b0;  assign sw3 = 1'b1;
  logic [1:0] vin = 2'b00;  wire [1:0] vout;  assign #(2,3,4) vout = vin;
  logic pin = 0;  wire pout;  assign #5 pout = pin;  int pchg = 0, p0;  always @(pout) pchg++;
  initial begin
    #1;
    ck("adder_concat_lhs", sum_out == 3 && carry_out == 1);
    ck("net_decl_assign_strength", mynet === 1'b1);
    ck("bus_select", busout === 4'h4);
    ck("var_continuous", vv === 1'b1);
    ck("strength_pull_beats_weak", sw === 1'b0);
    ck("default_strong_beats_weak", sw2 === 1'b0);
    ck("equal_strength_conflict", sw3 === 1'bx);
    #9 vin = 2'b01;
    #1 ck("rise_before", vout === 2'b00);
    #2 ck("rise_after", vout === 2'b01);
    #7 vin = 2'b00;
    #2 ck("fall_before", vout === 2'b01);
    #2 ck("fall_after", vout === 2'b00);
    #6 vin = 2'bzz;
    #3 ck("turnoff_before", vout === 2'b00);
    #2 ck("turnoff_after", vout === 2'bzz);
    #15 pin = 1;  p0 = pchg;
    #3 pin = 0;
    #7 ck("pulse_filtered", pchg == p0 && pout === 1'b0);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
