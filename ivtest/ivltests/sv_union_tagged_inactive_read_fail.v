module test;
  typedef union tagged {
    void Invalid;
    int Valid;
  } value_t;

  value_t value;
  int sink;

  initial begin
    value = tagged Invalid;
    sink = value.Valid;
  end
endmodule
