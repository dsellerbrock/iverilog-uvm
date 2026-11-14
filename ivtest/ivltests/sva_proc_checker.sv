// IEEE 1800-2023 17.3: procedural checker instances, after the c1 example.
// check_outside is static; check_inside and check_loop are procedural.
// Counters are indexed by instance: id for p1/p2 (check_loop passes the
// automatic v1, saved per queued instance, 16.14.6.1), pid for p0, which
// the checker's own always_ff runs for every instance at every clock.
`define MAX_SUM 8'd4
int p0p[32], p0f[32], p1p[32], p1f[32], p2p[32], p2f[32];

checker c1(event clk, logic [7:0] a, b, int id, int pid);
  logic [7:0] sum = 0;
  always_ff @(clk) begin
    sum <= a + 1'b1;
    p0: assert property (sum < `MAX_SUM) p0p[pid]++; else p0f[pid]++;
  end
  p1: assert property (@clk sum < `MAX_SUM) p1p[id]++; else p1f[id]++;
  p2: assert property (@clk a != b) p2p[id]++; else p2f[id]++;
endchecker

module top;
  logic clk = 0, en = 0;
  logic [7:0] in1 = 0, in2 = 1;
  logic [7:0] in_array [20:0];

  c1 check_outside(posedge clk, in1, in2, 30, 30);
  always @(posedge clk) begin
    automatic logic [7:0] v1 = 0;
    if (en) begin
      c1 check_inside(posedge clk, in1, v1, 31, 31);
    end
    // Named connections, queued at every clock: the same counts as the
    // static check_outside.
    c1 check_named(.clk(posedge clk), .a(in1), .b(in2), .id(29), .pid(29));
    for (int i = 0; i < 4; i++) begin
      v1 = v1 + 5;
      if (i != 2) begin
        c1 check_loop(posedge clk, in1, in_array[v1], v1, 2);
      end
    end
  end

  task automatic edge_with(input logic e, input logic [7:0] a, b);
    en = e; in1 = a; in2 = b;
    #5 clk = 1;
    #5 clk = 0;
  endtask

  initial begin
    for (int i = 0; i <= 20; i++) in_array[i] = i;
    #5;
    edge_with(0, 0, 1);
    edge_with(1, 1, 1);
    edge_with(1, 5, 0);
    edge_with(0, 10, 10);
    in_array[10] = 0;
    edge_with(1, 0, 3);
    edge_with(1, 20, 20);
    #1;
    $display("outside p0 %0d %0d p1 %0d %0d p2 %0d %0d",
             p0p[30], p0f[30], p1p[30], p1f[30], p2p[30], p2f[30]);
    $display("inside p0 %0d %0d p1 %0d %0d p2 %0d %0d",
             p0p[31], p0f[31], p1p[31], p1f[31], p2p[31], p2f[31]);
    $display("named p0 %0d %0d p1 %0d %0d p2 %0d %0d",
             p0p[29], p0f[29], p1p[29], p1f[29], p2p[29], p2f[29]);
    $display("loop p0 %0d %0d", p0p[2], p0f[2]);
    $display("loop v1=5 p1 %0d %0d p2 %0d %0d", p1p[5], p1f[5], p2p[5], p2f[5]);
    $display("loop v1=10 p1 %0d %0d p2 %0d %0d", p1p[10], p1f[10], p2p[10], p2f[10]);
    $display("loop v1=20 p1 %0d %0d p2 %0d %0d", p1p[20], p1f[20], p2p[20], p2f[20]);
    $finish;
  end
endmodule
