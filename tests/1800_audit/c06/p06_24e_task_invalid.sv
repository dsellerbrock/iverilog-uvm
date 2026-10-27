module p06_24e;
  typedef enum {red, green, blue, yellow} Colors;
  Colors col;
  initial begin
    col = green;
    $cast(col, 10);   $display("INFO task_invalid_1 col=%0d", col);
    $cast(col, -1);   $display("INFO task_invalid_2 col=%0d", col);
    $cast(col, 2);    $display("INFO task_valid col=%0d", col);
    $display("REACHED_END");
  end
endmodule
