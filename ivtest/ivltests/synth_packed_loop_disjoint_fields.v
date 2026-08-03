`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic [7:0] d;
    logic       de;
  } field_t;

  typedef struct packed {
    field_t [3:0] fields;
    logic   [3:0] status;
  } aggregate_t;

  logic [3:0][7:0] data;
  logic [3:0]       enable;
  logic [3:0]       status;
  aggregate_t       aggregate;

  // Generated register interfaces use separate combinational processes for
  // disjoint fields of one packed aggregate. A procedural loop index is a
  // constant in each synthesized iteration, so every selected field below is
  // unconditionally driven and must not be mistaken for a partial latch.
  always_comb begin : put_data
    for (int i = 0; i < 4; i++) begin
      aggregate.fields[i].d = data[i];
    end
  end

  always_comb begin : put_enable
    for (int i = 0; i < 4; i++) begin
      aggregate.fields[i].de = enable[i];
    end
  end

  always_comb aggregate.status = status;

  task automatic check(input logic [31:0] next_data,
                       input logic [3:0] next_enable,
                       input logic [3:0] next_status);
    data = next_data;
    enable = next_enable;
    status = next_status;
    #1;
    for (int i = 0; i < 4; i++) begin
      if (aggregate.fields[i].d !== data[i] ||
          aggregate.fields[i].de !== enable[i]) begin
        $display("FAILED -- field %0d: got %h/%b expected %h/%b",
                 i, aggregate.fields[i].d, aggregate.fields[i].de,
                 data[i], enable[i]);
        $finish;
      end
    end
    if (aggregate.status !== status) begin
      $display("FAILED -- status: got %h expected %h",
               aggregate.status, status);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(32'h12_34_56_78, 4'b1010, 4'h5);
    check(32'hde_ad_be_ef, 4'b0101, 4'ha);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
