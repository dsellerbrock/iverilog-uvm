`begin_keywords "1800-2012"

module main(
  input logic [3:0][7:0] data,
  input logic             override_data
);
  typedef struct packed {
    logic [7:0] d;
    logic       de;
  } field_t;

  typedef struct packed {
    field_t [3:0] fields;
  } aggregate_t;

  aggregate_t aggregate;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      aggregate.fields[i].d = data[i];
    end
  end

  // Exact loop-expanded ownership must still detect a genuine overlap.
  always_comb aggregate.fields[2].d = {8{override_data}};
endmodule

`end_keywords
