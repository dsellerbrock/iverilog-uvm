package p;
  typedef enum logic [7:0] {Zero = 8'h00, One = 8'h01} m_t;
  typedef struct packed {m_t read_lock, write_lock;} access_t;
endpackage

module dut;
  p::access_t [1:0] part_access;
endmodule

module top;
  dut dut();
  p::m_t [1:0] sample;
  initial begin
    sample[0] = p::One;
    force dut.part_access[0].read_lock = sample[0];
    release dut.part_access[0].read_lock;
  end
endmodule
