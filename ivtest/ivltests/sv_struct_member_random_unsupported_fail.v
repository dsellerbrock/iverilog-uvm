// These are legal IEEE random-variable shapes and compile in Slang. Icarus
// preserves that declaration polarity. At the actual randomize() use, the
// bounded VVP path must return failure for unsupported class-handle/dynamic-
// array members instead of reporting success while leaving them unchanged.
// Sparse enum members are supported and must stay inside their named domain.
class random_member_child;
  rand bit [7:0] value;
endclass

typedef enum bit [2:0] {
  RANDOM_MEMBER_A = 3'd1,
  RANDOM_MEMBER_B = 3'd3,
  RANDOM_MEMBER_C = 3'd6
} random_member_enum_t;

typedef struct {
  rand random_member_child child;
} handle_random_member_record_t;

class handle_random_member_item;
  rand handle_random_member_record_t record;
endclass

typedef struct {
  rand bit [7:0] dynamic_values[];
} dynamic_random_member_record_t;

class dynamic_random_member_item;
  rand dynamic_random_member_record_t record;
endclass

typedef struct {
  rand random_member_enum_t enum_value;
  randc random_member_enum_t enum_cycle;
} enum_random_member_record_t;

class enum_random_member_item;
  rand enum_random_member_record_t record;
endclass

module test;
  initial begin
    handle_random_member_item handle_item;
    dynamic_random_member_item dynamic_item;
    enum_random_member_item enum_item;
    bit enum_cycle_seen[8];
    bit seen_a, seen_b, seen_c;

    handle_item = new;
    handle_item.record.child = new;
    handle_item.rand_mode(0);
    if (handle_item.randomize() !== 1)
      $fatal(1, "disabled unsupported struct member blocked randomize");
    handle_item.rand_mode(1);
    if (handle_item.randomize() !== 0)
      $fatal(1, "unsupported struct class-handle randomization succeeded");

    dynamic_item = new;
    dynamic_item.record.dynamic_values = new[2];
    if (dynamic_item.randomize() !== 0)
      $fatal(1, "unsupported struct dynamic-array randomization succeeded");

    enum_item = new;
    enum_item.srandom(32'h1804_e001);
    for (int draw = 0; draw < 3; draw++) begin
      if (enum_item.randomize() !== 1)
        $fatal(1, "sparse enum member randomization failed");
      if (enum_cycle_seen[enum_item.record.enum_cycle])
        $fatal(1, "randc enum member repeated before exhausting its domain");
      enum_cycle_seen[enum_item.record.enum_cycle] = 1'b1;
      case (enum_item.record.enum_value)
        RANDOM_MEMBER_A, RANDOM_MEMBER_B, RANDOM_MEMBER_C: ;
        default: $fatal(1, "rand enum member escaped its declared domain");
      endcase
      case (enum_item.record.enum_cycle)
        RANDOM_MEMBER_A: seen_a = 1'b1;
        RANDOM_MEMBER_B: seen_b = 1'b1;
        RANDOM_MEMBER_C: seen_c = 1'b1;
        default: $fatal(1, "randc enum member escaped its declared domain");
      endcase
    end
    if (!(seen_a && seen_b && seen_c))
      $fatal(1, "enum member did not cover its declared domain");

    repeat (24) begin
      if (enum_item.randomize() !== 1)
        $fatal(1, "subsequent sparse enum randomization failed");
      if (!(enum_item.record.enum_value inside {
              RANDOM_MEMBER_A, RANDOM_MEMBER_B, RANDOM_MEMBER_C}))
        $fatal(1, "rand enum member escaped its declared domain");
      if (!(enum_item.record.enum_cycle inside {
              RANDOM_MEMBER_A, RANDOM_MEMBER_B, RANDOM_MEMBER_C}))
        $fatal(1, "randc enum member escaped its declared domain");
    end

    $display("PASSED");
  end
endmodule
