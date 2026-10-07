module main;
  int values[] = '{1, 2, 3};
  int doubled[];

  initial begin
    doubled = values.map() with (item * 2);
    if (doubled.size() != 3 || doubled[0] != 2
        || doubled[1] != 4 || doubled[2] != 6)
      $fatal(1, "map result mismatch: %p", doubled);
    $display("PASS: %p", doubled);
  end
endmodule
