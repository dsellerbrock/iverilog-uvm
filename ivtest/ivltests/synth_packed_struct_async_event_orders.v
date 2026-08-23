`begin_keywords "1800-2012"

module scalar_port_async_controls (
  input  logic clk,
  input  logic set,
  input  logic rst_n,
  input  logic data,
  output logic q_not,
  output logic q_eq
);
  // A packed-member actual is lowered through a fixed select before reaching
  // each scalar formal. Event and statement inputs must recover that source
  // symmetrically instead of mistaking reset for a second clock.
  always_ff @(posedge clk or posedge set or negedge rst_n) begin
    if (!rst_n)
      q_not <= 1'b0;
    else if (set)
      q_not <= 1'b1;
    else
      q_not <= data;
  end

  always_ff @(posedge clk or posedge set or negedge rst_n) begin
    if (rst_n == 1'b0)
      q_eq <= 1'b0;
    else if (set)
      q_eq <= 1'b1;
    else
      q_eq <= data;
  end
endmodule

module main;
  typedef struct packed {
    logic clk;
    logic set;
    logic rst_n;
    logic data;
  } controls_t;

  controls_t c;
  logic [5:0] q_not;
  logic [5:0] q_eq;
  logic q_port_not;
  logic q_port_eq;

  // Keep the predicate priority fixed while permuting all six source orders.
  // Synthesis must classify by precise source, never by event-list position.
  always_ff @(posedge c.clk or posedge c.set or negedge c.rst_n) begin
    if (!c.rst_n) q_not[0] <= 1'b0;
    else if (c.set) q_not[0] <= 1'b1;
    else q_not[0] <= c.data;
  end
  always_ff @(posedge c.clk or negedge c.rst_n or posedge c.set) begin
    if (!c.rst_n) q_not[1] <= 1'b0;
    else if (c.set) q_not[1] <= 1'b1;
    else q_not[1] <= c.data;
  end
  always_ff @(posedge c.set or posedge c.clk or negedge c.rst_n) begin
    if (!c.rst_n) q_not[2] <= 1'b0;
    else if (c.set) q_not[2] <= 1'b1;
    else q_not[2] <= c.data;
  end
  always_ff @(posedge c.set or negedge c.rst_n or posedge c.clk) begin
    if (!c.rst_n) q_not[3] <= 1'b0;
    else if (c.set) q_not[3] <= 1'b1;
    else q_not[3] <= c.data;
  end
  always_ff @(negedge c.rst_n or posedge c.clk or posedge c.set) begin
    if (!c.rst_n) q_not[4] <= 1'b0;
    else if (c.set) q_not[4] <= 1'b1;
    else q_not[4] <= c.data;
  end
  always_ff @(negedge c.rst_n or posedge c.set or posedge c.clk) begin
    if (!c.rst_n) q_not[5] <= 1'b0;
    else if (c.set) q_not[5] <= 1'b1;
    else q_not[5] <= c.data;
  end

  // Repeat every permutation with the equivalent explicit equality form.
  // The fixed member select must participate in polarity matching.
  always_ff @(posedge c.clk or posedge c.set or negedge c.rst_n) begin
    if (c.rst_n == 1'b0) q_eq[0] <= 1'b0;
    else if (c.set) q_eq[0] <= 1'b1;
    else q_eq[0] <= c.data;
  end
  always_ff @(posedge c.clk or negedge c.rst_n or posedge c.set) begin
    if (c.rst_n == 1'b0) q_eq[1] <= 1'b0;
    else if (c.set) q_eq[1] <= 1'b1;
    else q_eq[1] <= c.data;
  end
  always_ff @(posedge c.set or posedge c.clk or negedge c.rst_n) begin
    if (c.rst_n == 1'b0) q_eq[2] <= 1'b0;
    else if (c.set) q_eq[2] <= 1'b1;
    else q_eq[2] <= c.data;
  end
  always_ff @(posedge c.set or negedge c.rst_n or posedge c.clk) begin
    if (c.rst_n == 1'b0) q_eq[3] <= 1'b0;
    else if (c.set) q_eq[3] <= 1'b1;
    else q_eq[3] <= c.data;
  end
  always_ff @(negedge c.rst_n or posedge c.clk or posedge c.set) begin
    if (c.rst_n == 1'b0) q_eq[4] <= 1'b0;
    else if (c.set) q_eq[4] <= 1'b1;
    else q_eq[4] <= c.data;
  end
  always_ff @(negedge c.rst_n or posedge c.set or posedge c.clk) begin
    if (c.rst_n == 1'b0) q_eq[5] <= 1'b0;
    else if (c.set) q_eq[5] <= 1'b1;
    else q_eq[5] <= c.data;
  end

  scalar_port_async_controls through_scalar_ports (
    .clk(c.clk),
    .set(c.set),
    .rst_n(c.rst_n),
    .data(c.data),
    .q_not(q_port_not),
    .q_eq(q_port_eq)
  );

  (* ivl_synthesis_off *)
  initial begin
    c.clk = 1'b0;
    c.set = 1'b0;
    c.rst_n = 1'b1;
    c.data = 1'b0;

    c.data = 1'b1;
    #1 c.clk = 1'b1;
    #1 c.clk = 1'b0;
    if (q_not !== 6'h3f || q_eq !== 6'h3f
        || q_port_not !== 1'b1 || q_port_eq !== 1'b1)
      $fatal(1, "clocked data path mismatch: %h %h %b %b",
             q_not, q_eq, q_port_not, q_port_eq);

    c.rst_n = 1'b0;
    #1;
    if (q_not !== 6'h00 || q_eq !== 6'h00
        || q_port_not !== 1'b0 || q_port_eq !== 1'b0)
      $fatal(1, "asynchronous clear mismatch: %h %h %b %b",
             q_not, q_eq, q_port_not, q_port_eq);

    c.rst_n = 1'b1;
    #1 c.set = 1'b1;
    #1;
    if (q_not !== 6'h3f || q_eq !== 6'h3f
        || q_port_not !== 1'b1 || q_port_eq !== 1'b1)
      $fatal(1, "asynchronous set mismatch: %h %h %b %b",
             q_not, q_eq, q_port_not, q_port_eq);

    c.set = 1'b0;
    c.data = 1'b0;
    #1 c.clk = 1'b1;
    #1 c.clk = 1'b0;
    if (q_not !== 6'h00 || q_eq !== 6'h00
        || q_port_not !== 1'b0 || q_port_eq !== 1'b0)
      $fatal(1, "post-control data path mismatch: %h %h %b %b",
             q_not, q_eq, q_port_not, q_port_eq);

    $display("PASSED");
  end
endmodule

`end_keywords
