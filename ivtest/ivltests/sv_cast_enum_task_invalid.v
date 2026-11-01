module sv_cast_enum_task_invalid;
  typedef enum {red, green, blue, yellow} Colors;
  Colors col = green;
  bit cast_ok;

  initial begin
    $cast(col, 10);
    $display("after 10: col=%0d", col);

    $cast(col, -1);
    $display("after -1: col=%0d", col);

    cast_ok = $cast(col, 10);
    $display("function failure: ok=%0b col=%0d", cast_ok, col);

    $cast(col, 2);
    $display("after valid cast: col=%0d", col);
  end
endmodule
