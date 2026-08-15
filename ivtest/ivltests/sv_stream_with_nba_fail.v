// Slang 11 accepts this legal form. Icarus rejects it loudly until the NBA
// queue can snapshot the receiver, both range values, source, and target ID.
module test;
  logic [7:0] data[];
  int first = 0;
  int count = 2;
  initial {>>{data with [first +: count]}} <= 16'h1122;
endmodule
