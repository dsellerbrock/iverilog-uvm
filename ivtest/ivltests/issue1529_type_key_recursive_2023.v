module top;
  int matrix[2][2];
  typedef struct { int x; int y; } S;
  S items[2];

  initial begin
    matrix = '{int:7};
    items = '{int:5};
    if (matrix[0][0] !== 7 || matrix[0][1] !== 7 ||
        matrix[1][0] !== 7 || matrix[1][1] !== 7)
      $fatal(1, "multidimensional array type key failed");
    if (items[0].x !== 5 || items[0].y !== 5 ||
        items[1].x !== 5 || items[1].y !== 5)
      $fatal(1, "structure element type key failed");
    $display("PASS");
  end
endmodule
