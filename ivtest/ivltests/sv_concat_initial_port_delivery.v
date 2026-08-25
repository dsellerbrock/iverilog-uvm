typedef struct packed {
  logic [6:0] rsp_intg;
  logic [6:0] data_intg;
} concat_user_t;

typedef struct packed {
  logic         d_valid;
  logic [48:0]  middle;
  concat_user_t d_user;
  logic [1:0]   low;
} concat_rsp_t;

module concat_rsp_producer(output concat_rsp_t o);
  logic d_valid;
  logic [6:0] data_intg;

  always_comb d_valid = 1'b0;
  always_comb data_intg = '0;
  assign o = '{d_valid: d_valid, middle: '0,
               d_user: '{default: '0, data_intg: data_intg}, low: '0};
endmodule

module concat_rsp_passthrough(input concat_rsp_t i, output concat_rsp_t o);
  assign o = i;
endmodule

module concat_z_pair(input wire a, input wire b, output wire [1:0] y);
  assign y = {a, b};
endmodule

module concat_partial_source(input wire [1:0] p,
                             input wire a,
                             output wire [4:0] y);
  wire [3:0] full;
  assign full[1:0] = p;
  assign y = {full, a};
endmodule

module concat_strength_parts(input wire lo,
                             input wire hi,
                             output tri [2:0] bus);
  wire zbit;
  assign (weak0, strong1) bus[0] = lo;
  assign (pull0, weak1) bus[1] = zbit;
  assign (strong0, pull1) bus[2] = hi;
endmodule

module concat8_initial_stage(input wire [1:0] i, output wire [1:0] o);
  assign (weak0, strong1) o[0] = i[0];
  assign (weak0, strong1) o[1] = i[1];
endmodule

module sv_concat_initial_port_delivery;
  concat_rsp_t rsp_a;
  concat_rsp_t rsp_b;
  integer rsp_events = 0;
  integer rsp_torn = 0;
  integer failures = 0;

  concat_rsp_producer rsp_p(rsp_a);
  concat_rsp_passthrough rsp_q(rsp_a, rsp_b);

  always @(rsp_b) begin
    rsp_events = rsp_events + 1;
    RspZero_A: assert (rsp_b.d_valid -> ~|rsp_b.d_user.rsp_intg)
      else rsp_torn = rsp_torn + 1;
  end

  wire z_left;
  wire z_right;
  wire [1:0] z_pair;
  logic z_dyn;
  wire [2:0] z_middle = {z_pair, z_dyn};
  wire [3:0] z_observed = {1'b1, z_middle};
  concat_z_pair z_pair_i(z_left, z_right, z_pair);

  logic [1:0] partial_p;
  logic partial_a;
  wire [4:0] partial_y;
  wire [5:0] partial_observed = {1'b1, partial_y};
  concat_partial_source partial_i(partial_p, partial_a, partial_y);

  logic tree_a;
  logic tree_b;
  logic tree_c;
  logic tree_d;
  wire tree_z0;
  wire tree_z1;
  wire [5:0] tree_y = {tree_a, {0{tree_a}}, tree_z0, tree_b,
                       tree_c, {0{tree_b}}, tree_z1, tree_d};
  wire [6:0] tree_observed = {1'b1, tree_y};

  wire strength_lo;
  wire strength_hi;
  wire [2:0] strength_bus;
  wire [3:0] strength_observed = {1'b1, strength_bus};
  concat_strength_parts strength_i(strength_lo, strength_hi, strength_bus);
  integer strength_init_events = 0;
  integer strength_init_torn = 0;

  always @(strength_observed) begin
    if ($time == 0) begin
      strength_init_events = strength_init_events + 1;
      if (strength_observed !== 4'b1zzz)
        strength_init_torn = strength_init_torn + 1;
    end
  end

  wire [1:0] concat8_shallow;
  wire [1:0] concat8_deep;
  wire [3:0] concat8_pair;
  wire [4:0] concat8_observed = {1'b1, concat8_pair};
  integer concat8_events = 0;
  integer concat8_torn = 0;

  assign (strong0, strong1) concat8_shallow[0] = 1'b0;
  assign (strong0, strong1) concat8_shallow[1] = 1'b1;
  concat8_initial_stage concat8_stage_i(2'b10, concat8_deep);
  assign concat8_pair[1:0] = concat8_shallow;
  assign concat8_pair[3:2] = concat8_deep;

  always @(concat8_observed) begin
    concat8_events = concat8_events + 1;
    if (concat8_observed !== 5'b11010)
      concat8_torn = concat8_torn + 1;
  end

  initial begin
    z_dyn = 1'b0;
    partial_p = 2'b10;
    partial_a = 1'b0;
    tree_a = 1'b0;
    tree_b = 1'b1;
    tree_c = 1'b0;
    tree_d = 1'b1;

    #1;
    if (rsp_events != 2 || rsp_torn != 0 ||
        rsp_b.d_valid !== 1'b0 || rsp_b.d_user.rsp_intg !== '0) begin
      $display("rsp init FAILED events=%0d torn=%0d rsp=%b",
               rsp_events, rsp_torn, rsp_b);
      failures = failures + 1;
    end
    if (z_observed !== 4'b1zz0) begin
      $display("legitimate Z init FAILED value=%b", z_observed);
      failures = failures + 1;
    end
    if (partial_observed !== 6'b1zz100) begin
      $display("partial init FAILED value=%b", partial_observed);
      failures = failures + 1;
    end
    if (tree_observed !== 7'b10z10z1) begin
      $display("tree init FAILED value=%b", tree_observed);
      failures = failures + 1;
    end
    if (strength_observed !== 4'b1zzz || strength_init_events != 1 ||
        strength_init_torn != 0) begin
      $display("concat8 Z init FAILED value=%b events=%0d torn=%0d",
               strength_observed, strength_init_events, strength_init_torn);
      failures = failures + 1;
    end
    if (concat8_observed !== 5'b11010 || concat8_events != 1 ||
        concat8_torn != 0) begin
      $display("concat8 tree init FAILED value=%b events=%0d torn=%0d",
               concat8_observed, concat8_events, concat8_torn);
      failures = failures + 1;
    end

    z_dyn = 1'b1;
    partial_p = 2'b01;
    partial_a = 1'b1;
    tree_a = 1'b1;
    tree_b = 1'b0;
    tree_c = 1'b1;
    tree_d = 1'b0;
    force strength_lo = 1'b0;
    #1;
    if (z_observed !== 4'b1zz1) begin
      $display("legitimate Z update FAILED value=%b", z_observed);
      failures = failures + 1;
    end
    if (partial_observed !== 6'b1zz011) begin
      $display("partial update FAILED value=%b", partial_observed);
      failures = failures + 1;
    end
    if (tree_observed !== 7'b11z01z0) begin
      $display("tree update FAILED value=%b", tree_observed);
      failures = failures + 1;
    end
    if (strength_bus !== 3'bzz0) begin
      $display("concat8 lo force FAILED value=%b", strength_bus);
      failures = failures + 1;
    end

    force strength_hi = 1'b1;
    #1;
    if (strength_bus !== 3'b1z0) begin
      $display("concat8 hi force FAILED value=%b", strength_bus);
      failures = failures + 1;
    end

    force strength_lo = 1'b1;
    #1;
    if (strength_bus !== 3'b1z1) begin
      $display("concat8 update FAILED value=%b", strength_bus);
      failures = failures + 1;
    end

    release strength_lo;
    #1;
    if (strength_bus !== 3'b1zz) begin
      $display("concat8 lo release FAILED value=%b", strength_bus);
      failures = failures + 1;
    end

    release strength_hi;
    z_dyn = 1'b0;
    partial_p = 2'b11;
    partial_a = 1'b0;
    #1;
    if (strength_bus !== 3'bzzz) begin
      $display("concat8 hi release FAILED value=%b", strength_bus);
      failures = failures + 1;
    end
    if (z_observed !== 4'b1zz0) begin
      $display("legitimate Z second update FAILED value=%b", z_observed);
      failures = failures + 1;
    end
    if (partial_observed !== 6'b1zz110) begin
      $display("partial second update FAILED value=%b", partial_observed);
      failures = failures + 1;
    end

    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED failures=%0d", failures);
  end
endmodule
