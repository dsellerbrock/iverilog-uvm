`begin_keywords "1800-2012"

// A defined negative packed-property offset is carried in one signed 64-bit
// VVP index word. Constants outside that range are wholly out of bounds, and
// INT64_MIN must not be mistaken for integer zero by the target's older
// 32-bit immediate helper. Every out-of-bounds write is a no-op, while its RHS
// is still evaluated exactly once. Dynamic signed and unsigned 64-bit bases
// must also remain distinct: unsigned UINT64_MAX is not signed -1.
class property_extreme_negative_c;
  logic [7:0] value;
endclass

module sv_property_extreme_negative_offset;
  property_extreme_negative_c obj;
  int fails;
  int rhs_calls;
  longint signed signed_offset;
  longint unsigned unsigned_offset;

  function automatic logic [1:0] evaluated_rhs(input logic [1:0] value);
    rhs_calls++;
    return value;
  endfunction

  initial begin
    obj = new;
    fails = 0;
    rhs_calls = 0;

    // INT64_MIN used to be replaced with offset zero, corrupting bits [1:0].
    obj.value = 8'ha4;
    obj.value[64'sh8000_0000_0000_0000 +: 2] = evaluated_rhs(2'b11);
    if (obj.value !== 8'ha4 || rhs_calls != 1) begin
      $display("FAILED INT64_MIN: value=%h calls=%0d", obj.value, rhs_calls);
      fails++;
    end

    // A negative value outside int64_t is necessarily wholly out of range.
    obj.value = 8'h5a;
    obj.value[65'sh1_0000_0000_0000_0000 +: 2] = evaluated_rhs(2'b11);
    if (obj.value !== 8'h5a || rhs_calls != 2) begin
      $display("FAILED below INT64_MIN: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    // A representable negative constant outside the 32-bit compact-immediate
    // range must retain its signed value rather than aliasing offset zero.
    obj.value = 8'h3c;
    obj.value[64'shffff_ffff_8000_0000 +: 2] = evaluated_rhs(2'b11);
    if (obj.value !== 8'h3c || rhs_calls != 3) begin
      $display("FAILED negative 2**31: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    // A small negative base can partially overlap and remains supported:
    // source bit 1 lands at destination bit zero.
    obj.value = 8'ha4;
    obj.value[64'shffff_ffff_ffff_ffff +: 2] = evaluated_rhs(2'b10);
    if (obj.value !== 8'ha5 || rhs_calls != 4) begin
      $display("FAILED negative overlap: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    // The largest compact positive offset used to wrap `bitoff + i` in the
    // blocking property-store opcode and alias destination bit zero.
    obj.value = 8'h96;
    obj.value[32'hffff_ffff +: 2] = evaluated_rhs(2'b11);
    if (obj.value !== 8'h96 || rhs_calls != 5) begin
      $display("FAILED UINT32_MAX: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    // A run-time signed -1 base partially overlaps bit zero.
    signed_offset = -1;
    obj.value = 8'ha4;
    obj.value[signed_offset +: 2] = evaluated_rhs(2'b10);
    if (obj.value !== 8'ha5 || rhs_calls != 6) begin
      $display("FAILED dynamic signed -1: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    // The same all-ones word is a huge positive base when its source
    // expression is unsigned. Treating it as signed -1 corrupts bit zero.
    unsigned_offset = '1;
    obj.value = 8'h96;
    obj.value[unsigned_offset +: 2] = evaluated_rhs(2'b10);
    if (obj.value !== 8'h96 || rhs_calls != 7) begin
      $display("FAILED dynamic UINT64_MAX: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    if (fails == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED (%0d cases)", fails);
  end
endmodule

`end_keywords
