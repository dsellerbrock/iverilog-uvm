// IEEE 1800-2017 and IEEE 1800-2023 6.19.5.3, 6.19.5.4, 6.19.5.6.
module enum_width_check #(parameter integer WIDTH = 1)(output bit done = 0);
  typedef enum bit signed [WIDTH-1:0] {B_ZERO = 0, B_NEG = -1} b_t;
  typedef enum logic [WIDTH-1:0] {L_ZERO = '0, L_ONE = '1,
                                L_X = 'x, L_Z = 'z} l_t;
  b_t b;
  l_t l;
  integer which;
  initial begin
    for (which = 0; which < 6; which = which + 1) begin
    case (which)
      0: begin
        b = B_NEG;
        if (b.name() != "B_NEG") $fatal(1, "signed name width %0d", WIDTH);
        b = B_ZERO;
        if (b.name() != "B_ZERO") $fatal(1, "zero name width %0d", WIDTH);
      end
      1: begin
        b = B_NEG;
        if (b.next() !== B_ZERO || b.next(0) !== B_NEG ||
            b.next(2) !== B_NEG || b.next(3) !== B_ZERO)
          $fatal(1, "signed next width %0d", WIDTH);
      end
      2: begin
        b = B_ZERO;
        if (b.prev() !== B_NEG || b.prev(0) !== B_ZERO ||
            b.prev(2) !== B_ZERO || b.prev(3) !== B_NEG)
          $fatal(1, "signed prev width %0d", WIDTH);
      end
      3: begin
        l = L_X;
        if (l.name() != "L_X") $fatal(1, "X name width %0d", WIDTH);
        l = L_Z;
        if (l.name() != "L_Z") $fatal(1, "Z name width %0d", WIDTH);
        l = L_ONE;
        if (l.name() != "L_ONE") $fatal(1, "ones name width %0d", WIDTH);
        l = L_ZERO;
        if (l.name() != "L_ZERO") $fatal(1, "zero name width %0d", WIDTH);
      end
      4: begin
        l = L_X;
        if (l.next() !== L_Z || l.next(2) !== L_ZERO || l.next(0) !== L_X)
          $fatal(1, "X next width %0d", WIDTH);
        l = L_Z;
        if (l.next() !== L_ZERO) $fatal(1, "Z next width %0d", WIDTH);
      end
      5: begin
        l = L_Z;
        if (l.prev() !== L_X || l.prev(3) !== L_ZERO || l.prev(0) !== L_Z)
          $fatal(1, "Z prev width %0d", WIDTH);
        l = L_ZERO;
        if (l.prev() !== L_Z) $fatal(1, "zero prev width %0d", WIDTH);
      end
      default: $fatal(1, "bad test case");
    endcase
    end
    done = 1;
  end
endmodule

typedef enum bit {HOST, DEVICE} scalar_mode_t;
class enum_carrier;
  scalar_mode_t mode;
  function void check();
    if (mode.name() != "DEVICE" || mode.next() !== HOST || mode.prev() !== HOST)
      $fatal(1, "class enum methods");
  endfunction
endclass

module main;
  wire [5:0] done;
  enum_width_check #(1) w1(done[0]);
  enum_width_check #(2) w2(done[1]);
  enum_width_check #(31) w31(done[2]);
  enum_width_check #(32) w32(done[3]);
  enum_width_check #(33) w33(done[4]);
  enum_width_check #(64) w64(done[5]);
  typedef enum bit [63:0] {A = 64'h1, B = 64'h8000000100000001,
                          C = 64'h4000000100000002} wide_t;
  typedef enum logic [64:0] {ZERO = '0, ONES = '1, EX = 'x, ZED = 'z} logic65_t;
  typedef struct packed {bit pad; scalar_mode_t mode;} packed_t;
  wide_t wide_value;
  logic65_t logic_value;
  packed_t packed_value;
  enum_carrier object_value;
  initial begin
    wide_value = B;
    if (wide_value.name() != "B") $fatal(1, "wide name");
    wide_value = A;
    if (wide_value.next() !== B || wide_value.prev() !== C)
      $fatal(1, "wide method return");
    if (wide_value.next(0) !== A || wide_value.prev(3) !== A ||
        wide_value.next(4) !== B || wide_value.prev(4) !== C ||
        wide_value.next(32'hffffffff) !== A || wide_value.prev(-1) !== A)
      $fatal(1, "three-member full-cycle/unsigned count");
    logic_value = EX;
    if (logic_value.name() != "EX" || logic_value.next() !== ZED ||
        logic_value.prev() !== ONES) $fatal(1, "65-bit X methods");
    logic_value = ZED;
    if (logic_value.name() != "ZED" || logic_value.next() !== ZERO ||
        logic_value.prev() !== EX) $fatal(1, "65-bit Z methods");
    packed_value.mode = DEVICE;
    if (packed_value.mode.name() != "DEVICE" || packed_value.mode.next() !== HOST ||
        packed_value.mode.prev() !== HOST) $fatal(1, "packed member methods");
    object_value = new;
    object_value.mode = DEVICE;
    object_value.check();
    if (object_value.mode.name() != "DEVICE") $fatal(1, "class property name");
    #1;
    if (done !== '1) $fatal(1, "width checks did not finish");
    $display("PASSED");
  end
endmodule
