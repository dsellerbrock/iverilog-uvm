// IEEE 1800-2017/2023 10.9.2: each structure-pattern member is evaluated
// in the assignment context of its corresponding member.
typedef enum logic [1:0] {RW_IDLE = 2'b00, RW_READ = 2'b01} mode_t;
typedef struct packed {mode_t rd_wr_en; logic [13:0] addr;} mem_if_t;

module main;
  logic [13:0] locked_src_addr = 0;
  logic [31:0] num_mem_operands = 2;
  mem_if_t bad, good;

  initial begin
    bad <= '{rd_wr_en: RW_READ, addr: locked_src_addr + num_mem_operands};
    good <= '{rd_wr_en: RW_READ,
              addr: 14'(locked_src_addr + num_mem_operands)};
    #1;
    if (bad !== 16'h4002 || good !== 16'h4002)
      $fatal(1, "bad=%h good=%h", bad, good);
    $display("PASSED");
  end
endmodule
