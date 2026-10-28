typedef struct packed { logic [1:0] field; } packed_t;
typedef enum logic [1:0] { ENUM_ZERO, ENUM_ONE } enum_t;

module top;
  wire [1:0] arr [3:2];
  wire [1:0][2:3] mda;
  wire packed_t packed_net;
  wire enum_t enum_net;
  logic [1:0] var_arr [3:2];

  assign arr[3] = 2'b01;
  assign arr[2] = 2'b10;
  assign mda = 4'b1001;
  assign packed_net = '0;
  assign enum_net = ENUM_ZERO;

  initial begin
    var_arr[3] = 2'b11;
    var_arr[2] = 2'b01;
    #0;
    $probe_vpi_array_member;
    $finish;
  end
endmodule
