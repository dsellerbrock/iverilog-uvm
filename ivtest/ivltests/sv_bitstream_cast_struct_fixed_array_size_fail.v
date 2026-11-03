typedef struct {
  byte members[2];
  bit tag;
} destination_t;

module test;
  logic [15:0] source_value;
  destination_t destination;
  initial destination = destination_t'(source_value);
endmodule
