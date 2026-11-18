// IEEE 1800-2017 21.2.1.7 / IEEE 1800-2023 21.2.1.6
typedef struct packed {
  logic [2:0] n;
  bit valid;
} payload_t;

class holder;
  payload_t p;
endclass

typedef enum logic signed [2:0] {
  NEG = -3'sd2,
  UNKNOWN = 3'bx01,
  HIGH_Z = 3'bz01
} state_t;

typedef struct packed {
  payload_t inner;
  logic signed [4:0] delta;
  state_t state;
  logic [96:0] wide;
  logic [2:0] unknown;
  logic [2:0] high_z;
  bit [2:0] two_state;
} details_t;

typedef struct {
  details_t item;
} record_t;

class collection;
  record_t record;
  payload_t descending [4:3][0:1];
  payload_t singleton [7:7];
endclass

module issue3782;
  payload_t p;
  details_t details;
  holder h;
  collection c;

  initial begin
    p = '{n:3, valid:1};
    h = new;
    h.p = p;
    $display("TOP=%p", p);
    $display("NESTED=%p", h);

    details = {p, -5'sd7, NEG, 97'h1_0000_0000_0000_0000_0000_0003,
               3'bxxx, 3'bzzz, 3'b1xz};
    $display("FIELDS=%p", details);
    details.state = UNKNOWN;
    c = new;
    c.record.item = details;
    c.descending[4][0] = '{n:1, valid:0};
    c.descending[4][1] = '{n:2, valid:1};
    c.descending[3][0] = '{n:3, valid:0};
    c.descending[3][1] = '{n:4, valid:1};
    c.singleton[7] = '{n:7, valid:1};
    $display("ARRAYS=%p", c);
    $display("RECORD=%p", c.record);
    $display("ARRAY_PROPERTY=%p", c.descending);
    $display("PROPERTY=%p ELEMENT=%p", h.p, c.descending[3][1]);

    details.state = HIGH_Z;
    $display("ENUM_Z=%p", details);
    details.state = state_t'(3'bx10);
    $display("ENUM_INVALID_X=%p", details);
    details.state = state_t'(-1);
    $display("ENUM_INVALID_SIGNED=%p", details);
  end
endmodule
