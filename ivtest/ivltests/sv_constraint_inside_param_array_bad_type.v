module top;
  parameter string LABELS[] = {"read", "write"};
  bit [7:0] opcode;
  initial begin
    if (std::randomize(opcode) with { opcode inside {LABELS}; })
      $fatal(1, "unsupported string membership was accepted");
  end
endmodule
