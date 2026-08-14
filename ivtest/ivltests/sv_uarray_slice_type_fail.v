module test;
  typedef enum bit [1:0] { EA0, EA1 } enum_a_t;
  typedef enum bit [1:0] { EB0, EB1 } enum_b_t;
  enum_a_t enum_a [3:0];
  enum_b_t enum_b [3:0];
  bit two_state [3:0];
  logic four_state [3:0];

  initial begin
    enum_a[1:0] = enum_b[1:0];
    if (enum_a[1:0] == enum_b[1:0]) begin end
    two_state[1:0] = four_state[1:0];
    if (two_state[1:0] == four_state[1:0]) begin end
  end
endmodule
