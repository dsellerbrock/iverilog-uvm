module sv_array_map_2017_fail;
  int source[] = '{1, 2};
  int mapped[];

  initial mapped = source.map() with (item + 1);
endmodule
