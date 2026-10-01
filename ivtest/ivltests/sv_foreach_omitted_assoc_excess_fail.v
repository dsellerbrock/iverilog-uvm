// The associative rank has one fixed child and one packed int rank.
module top;
  int map[int][3:1];
  initial foreach (map[,bank,bit_index,extra])
    $fatal(1, "excess foreach rank was accepted");
endmodule
