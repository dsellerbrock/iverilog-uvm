// Variable invalid ranges are diagnosed at their single evaluation point.
// Fixed-array OOB unpack clips to in-range elements; bounded queues truncate.
module test;
  logic [7:0] d[];
  logic [7:0] f[4:2];
  logic [7:0] q[$:2];
  logic [7:0] uq[$];
  integer first;
  integer last;
  logic signed [63:0] extreme;
  int errors;
  initial begin
    d = '{8'haa, 8'hbb};
    first = 'x;
    {>>{d with [first +: 1]}} = 8'h11;
    if (d.size() != 2 || d[0] != 8'haa || d[1] != 8'hbb) errors += 1;

    extreme = 64'sh8000_0000_0000_0000;
    {>>{d with [extreme +: 1]}} = 8'h22;
    if (d.size() != 2 || d[0] != 8'haa || d[1] != 8'hbb) errors += 1;

    f = '{8'h44, 8'h33, 8'h22};
    first = 1;
    last = 4;
    {>>{f with [first : last]}} = 32'h10203040;
    if (f[4] != 8'h40 || f[3] != 8'h30 || f[2] != 8'h20) errors += 1;

    q = '{8'haa};
    first = 1;
    last = 4;
    {>>{q with [first +: last]}} = 32'h11223344;
    if (q.size() != 3 || q[0] != 8'haa || q[1] != 8'h11
        || q[2] != 8'h22) errors += 1;

    d = '{8'haa, 8'hbb};
    first = 1048576;
    {>>{d with [first]}} = 8'h55;
    if (d.size() != 2 || d[0] != 8'haa || d[1] != 8'hbb) errors += 1;

    uq = '{8'hcc};
    {>>{uq with [first]}} = 8'h66;
    if (uq.size() != 1 || uq[0] != 8'hcc) errors += 1;

    if (errors == 0) $display("PASSED");
    else $display("FAILED: %0d checks", errors);
  end
endmodule
