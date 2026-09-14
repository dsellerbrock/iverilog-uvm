// L42: an integral (int/byte/shortint/bit/logic) class property read or
// written as a string used to fall through to vvp's
// class_property_t::get_string/set_string base-class "unsupported" stub
// (warn once, return ""/ignore write) since property_atom<T> and
// property_logic never overrode it -- unlike a plain (non-property)
// vec4-typed variable, which already gets the correct IEEE
// 1800-2017/2023 6.16 packed-byte conversion. Fixed by giving both
// classes real get_string/set_string overrides sharing the same
// conversion a plain variable's %pushv/str opcode already uses.
module test;
  class c1;
    int val;
    byte b;
    shortint sh;
    bit [31:0] bv;
    logic [31:0] lv;
  endclass

  c1 obj;
  string s;
  int errors;

  initial begin
    errors = 0;
    obj = new;

    // read: int property -> string (packed bytes, leading zero bytes dropped)
    obj.val = 42; // 0x2A = '*'
    s = obj.val;
    if (s != "*") begin
      $display("FAILED: int read got '%s' (%0d chars)", s, s.len());
      errors++;
    end

    // read: zero value -> empty string (every byte dropped)
    obj.val = 0;
    s = obj.val;
    if (s != "") begin
      $display("FAILED: zero read got '%s' len=%0d", s, s.len());
      errors++;
    end

    // read: byte property
    obj.b = 8'h41;
    s = obj.b;
    if (s != "A") begin
      $display("FAILED: byte read got '%s'", s);
      errors++;
    end

    // read: bit vector property
    obj.bv = 32'h41;
    s = obj.bv;
    if (s != "A") begin
      $display("FAILED: bit vector read got '%s'", s);
      errors++;
    end

    // read: logic vector property
    obj.lv = 32'h41;
    s = obj.lv;
    if (s != "A") begin
      $display("FAILED: logic vector read got '%s'", s);
      errors++;
    end

    // write: string -> int property, zero-filled on the left
    obj.val = "*";
    if (obj.val != 32'h0000002a) begin
      $display("FAILED: int write got 0x%h", obj.val);
      errors++;
    end

    // write: string longer than target width, truncated on the left
    obj.val = "hello";
    if (obj.val != 32'h656c6c6f) begin // "ello"
      $display("FAILED: int write truncation got 0x%h", obj.val);
      errors++;
    end

    // write: string -> shortint property
    obj.sh = "A";
    if (obj.sh != 16'h0041) begin
      $display("FAILED: shortint write got 0x%h", obj.sh);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
