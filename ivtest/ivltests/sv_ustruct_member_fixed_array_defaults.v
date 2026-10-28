module sv_ustruct_member_fixed_array_defaults;
  typedef byte bytes_t[2];
  typedef struct {
    byte direct_data[2] = '{2{1}};
    bytes_t typedef_data = '{2{2}};
  } packet_t;

  packet_t implicit_value;
  packet_t explicit_value = '{'{3, 4}, '{5, 6}};

  initial begin
    if (implicit_value.direct_data[0] !== 1 ||
        implicit_value.direct_data[1] !== 1 ||
        implicit_value.typedef_data[0] !== 2 ||
        implicit_value.typedef_data[1] !== 2)
      $fatal(1, "fixed-size array member defaults");

    if (explicit_value.direct_data[0] !== 3 ||
        explicit_value.direct_data[1] !== 4 ||
        explicit_value.typedef_data[0] !== 5 ||
        explicit_value.typedef_data[1] !== 6)
      $fatal(1, "whole-struct initializer suppression");

    $display("PASSED");
    $finish;
  end
endmodule
