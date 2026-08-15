// IEEE 1800-2023 11.4.14.4 blocking streaming-with semantics over
// dynamic, queue, ascending fixed, descending fixed, logic, and bit arrays.
module test;
  logic [7:0] d[];
  bit [7:0] bd[];
  logic [7:0] q[$];
  logic [7:0] fd [5:2];
  logic [7:0] fa [2:5];
  logic [7:0] lf [4:2];
  bit [7:0] bf [4:2];
  logic [7:0] lt [2:0];
  bit [7:0] bt [2:0];
  logic [31:0] got;
  integer first;
  integer count;
  int errors;

  task automatic check(input bit ok, input string what);
    if (!ok) begin
      errors += 1;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    d = '{8'ha1, 8'hb2, 8'hc3, 8'hd4};
    got = {>>{d with [1 +: 2]}};
    check(got == 32'hb2c3_0000, "dynamic source selection and resizing");
    {>>{d with [1 +: 2]}} = 16'h1122;
    check(d.size() == 4 && d[0] == 8'ha1 && d[1] == 8'h11
          && d[2] == 8'h22 && d[3] == 8'hd4,
          "dynamic target preserves unselected elements");

    d = '{8'h10, 8'h20};
    bd = '{8'h10, 8'h20};
    first = -1;
    count = 3;
    got = {>>{d with [first +: count]}};
    check(got === 32'hxx10_2000,
          "dynamic logic source OOB contributes X default");
    got = {>>{bd with [first +: count]}};
    check(got == 32'h0010_2000,
          "dynamic bit source OOB contributes zero default");

    q = '{};
    {>>{q with [1 : 2]}} = 16'h3344;
    check(q.size() == 3 && q[0] == 0 && q[1] == 8'h33
          && q[2] == 8'h44, "queue target grows to selected indexes");

    fd = '{8'h50, 8'h40, 8'h30, 8'h20};
    fa = '{8'h20, 8'h30, 8'h40, 8'h50};
    got = {>>{fd with [5 : 3]}};
    check(got == 32'h5040_3000, "descending fixed source range");
    got = {>>{fa with [3 +: 2]}};
    check(got == 32'h3040_0000, "ascending fixed source indexed range");
    {>>{fd with [4 -: 2]}} = 16'h7788;
    {>>{fa with [3 +: 2]}} = 16'h99aa;
    check(fd[5] == 8'h50 && fd[4] == 8'h77 && fd[3] == 8'h88
          && fd[2] == 8'h20, "descending fixed target range");
    check(fa[2] == 8'h20 && fa[3] == 8'h99 && fa[4] == 8'haa
          && fa[5] == 8'h50, "ascending fixed target range");

    d = '{};
    q = '{};
    {>>{q with [0 +: 2], d}} = 32'h1020_3040;
    check(q.size() == 2 && q[0] == 8'h10 && q[1] == 8'h20
          && d.size() == 2 && d[0] == 8'h30 && d[1] == 8'h40,
          "ranged member precedes greedy unbounded member");

    lf = '{8'h40, 8'h30, 8'h20};
    bf = '{8'h40, 8'h30, 8'h20};
    first = 3;
    count = 4;
    got = {>>{lf with [first +: count]}};
    check(got === 32'h3040_xxxx, "logic fixed source keeps OOB X");
    got = {>>{bf with [first +: count]}};
    check(got == 32'h3040_0000, "bit fixed source coerces OOB X to zero");

    lt = '{default:8'h00};
    bt = '{default:8'h00};
    {>>{lt with [1]}} = 8'bx1z0_110x;
    {>>{bt with [1]}} = 8'bx1z0_110x;
    check(lt[1] === 8'bx1z0_110x, "direct fixed logic target keeps X/Z");
    check(bt[1] == 8'b0100_1100, "direct fixed bit target coerces X/Z");

    if (errors == 0) $display("PASSED");
    else $display("FAILED: %0d checks", errors);
  end
endmodule
