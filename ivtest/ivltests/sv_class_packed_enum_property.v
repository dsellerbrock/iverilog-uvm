// A packed array of enum values remains packed when used as a class property.
// Keep an unpacked typedef next to it to catch accidental array-kind changes.
module sv_class_packed_enum_property;
  typedef enum logic [3:0] { MubiTrue = 4'h6, MubiFalse = 4'h9 } mubi_t;
  typedef mubi_t [3:0] packed_t;
  typedef logic [7:0] byte_t;
  typedef byte_t unpacked_t [1:0];

  class holder;
    rand packed_t idle;
    unpacked_t bytes;

    task check();
      idle = {4{MubiTrue}};
      if (idle !== 16'h6666) $fatal(1, "packed enum replication");
      idle = '1;
      if (idle !== 16'hffff) $fatal(1, "packed enum fill");
      bytes = {8'h12, 8'h34};
      if (bytes[1] !== 8'h12 || bytes[0] !== 8'h34)
        $fatal(1, "unpacked array concatenation");
    endtask
  endclass

  holder h;
  initial begin
    h = new;
    h.check();
    $display("PASSED");
  end
endmodule
