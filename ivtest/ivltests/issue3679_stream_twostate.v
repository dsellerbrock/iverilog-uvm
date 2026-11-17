module test;
  logic [7:0] v = 8'b1x0z0101;
  bit [7:0] a, b;
  bit [3:0] bq[$];
  logic [3:0] q[$];
  logic [7:0] d[];
  logic [7:0] four;
  int errors = 0;

  initial begin
    {>>{a}} = v;
    if (a !== 8'h85) errors++;
    {>>{a, q, b}} = {v, v, v};
    if (a !== 8'h85 || b !== 8'h85 || q.size() != 2 ||
        q[0] !== 4'b1x0z || q[1] !== 4'b0101) errors++;
    {>>{a, bq}} = {v, v};
    if (a !== 8'h85 || bq.size() != 2 || bq[0] !== 4'h8 || bq[1] !== 4'h5) errors++;
    {>>{four, d, b}} = {v, v, v};
    if (four !== v || b !== 8'h85 || d.size() != 1 || d[0] !== v) errors++;
    {>>{a, q with [0 +: 2], b}} = {v, v, v};
    if (a !== 8'h85 || b !== 8'h85 || q.size() != 2 ||
        q[0] !== 4'b1x0z || q[1] !== 4'b0101) errors++;
    if (errors) $display("FAILED: %0d checks", errors);
    else $display("PASSED");
  end
endmodule
