// Bit and part selects of a class property whose type is an enum or a packed
// struct, and of an element of an unpacked array of them (IEEE 1800-2017/2023
// 6.19.4, 7.4, 11.5.1). The read was treated as an array index: `e[3:0]' gave
// zeros and `e[0]' gave the whole value (OpenTitan usbdev: `m_pid_type[3:0] ^
// m_pid_type[7:4]' never saw a valid PID, so the scoreboard predicted an error
// the DUT never raised). Part-select writes were rejected as missing casts.
typedef enum bit [7:0] { PID_SETUP = 8'b0010_1101, PID_OUT = 8'b1110_0001 } pid_e;
typedef enum logic [3:0] { L0 = 4'h5, L1 = 4'ha } nib_e;
typedef struct packed { logic [3:0] hi; logic [3:0] lo; } pair_t;

class item;
  pid_e pid;
  nib_e nib;
  pair_t pair;
  pid_e pids[2];
  pair_t pairs[2];
  pid_e q[$];
  int unsigned idx = 2;
  function new();
    pid = PID_SETUP; nib = L1; pair = 8'hc3;
    pids[1] = PID_OUT; pairs[1] = 8'h5a; q.push_back(PID_SETUP);
  endfunction
  function bit valid_pid();
    return (pid[3:0] ^ pid[7:4]) == 4'hf;
  endfunction
endclass

module main;
  int errors;
  item it;
  initial begin
    it = new;
    if (it.valid_pid() !== 1'b1) begin $display("FAILED valid_pid"); errors++; end
    if (it.pid[3:0] !== 4'b1101 || it.pid[7:4] !== 4'b0010) begin
      $display("FAILED pid halves %b %b", it.pid[3:0], it.pid[7:4]); errors++;
    end
    if (it.pid[0] !== 1'b1 || it.pid[7] !== 1'b0 || it.pid[it.idx] !== 1'b1) begin
      $display("FAILED pid bits"); errors++;
    end
    if (it.nib[2:1] !== 2'b01 || it.nib[3] !== 1'b1) begin
      $display("FAILED nib %b %b", it.nib[2:1], it.nib[3]); errors++;
    end
    if (it.pair[3:0] !== 4'h3 || it.pair[7:4] !== 4'hc || it.pair[7] !== 1'b1) begin
      $display("FAILED pair"); errors++;
    end
    if (it.pids[1][3:0] !== 4'h1 || it.pids[1][7:4] !== 4'he) begin
      $display("FAILED pids[1] %b %b", it.pids[1][3:0], it.pids[1][7:4]); errors++;
    end
    if (it.pairs[1][7:4] !== 4'h5 || it.pairs[1][0] !== 1'b0) begin
      $display("FAILED pairs[1]"); errors++;
    end
    if (it.q[0][3:0] !== 4'b1101) begin $display("FAILED q[0]"); errors++; end

    it.pid[3:0] = 4'h1;
    it.nib[3:2] = 2'b01;
    it.pair[7:4] = 4'h1;
    it.pair[0] = 1'b0;
    it.pids[0][7:4] = 4'h9;
    it.pairs[1][3:0] = 4'h7;
    it.pid[it.idx] = 1'b1;
    if (it.pid !== 8'b0010_0101) begin $display("FAILED pid write %b", it.pid); errors++; end
    if (it.nib !== 4'b0110) begin $display("FAILED nib write %b", it.nib); errors++; end
    if (it.pair !== 8'h12) begin $display("FAILED pair write %h", it.pair); errors++; end
    if (it.pids[0][7:4] !== 4'h9) begin $display("FAILED pids write"); errors++; end
    if (it.pairs[1] !== 8'h57) begin $display("FAILED pairs write %h", it.pairs[1]); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
