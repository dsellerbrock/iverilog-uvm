module issue2471_struct_dynamic_nested;
  typedef struct { byte unsigned h; bit [7:0] values[][]; } rec_t;
  rec_t s, s2;
  bit [7:0] row[];

  initial begin
    s.values = new[2];
    s.values[0] = new[1];
    s.values[1] = new[2];
    s.values[0][0] = 8'hA5;
    s.values[1][1] = 8'h5A;
    s2 = s;
    s2.values[0][0] = 8'h11;
    row = s.values[1];

    if (s.values.size() != 2 || s.values[1].size() != 2
        || s.values[0][0] != 8'hA5 || s.values[1][1] != 8'h5A
        || row.size() != 2 || s2.values.size() != 2
        || s2.values[0][0] != 8'h11)
      $fatal(1, "unexpected nested dynamic-array struct member result");

    $display("s %0d %0d %h %h %0d", s.values.size(),
             s.values[1].size(), s.values[0][0], s.values[1][1], row.size());
    $display("s2 %0d %h", s2.values.size(), s2.values[0][0]);
  end
endmodule
