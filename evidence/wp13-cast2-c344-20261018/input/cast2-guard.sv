module check;
  bit [7:0] whole = 8'h0f;
  bit [7:0] edge_value = 8'h55;
  logic [7:0] four = 8'hx1;
  initial begin
    whole += 8'd1;
    if (whole !== 8'h10) $fatal(1, "whole two-state update");
    edge_value[8 +: 2] += 2'b01;
    if (edge_value !== 8'h55) $fatal(1, "out-of-range update");
    four ^= 8'd0;
    if (four !== 8'hx1) $fatal(1, "four-state preservation");
    $display("PASS");
  end
endmodule
