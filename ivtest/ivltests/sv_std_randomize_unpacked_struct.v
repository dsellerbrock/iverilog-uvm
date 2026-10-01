// IEEE 1800-2017/2023 18.12: scope randomization traverses an unpacked
// struct variable and writes every integral member.
class clock_worker;
  typedef struct {
    bit [5:0] io_delay;
    bit [5:0] main_delay;
    logic [5:0] usb_delay;
  } clock_delays_t;
  typedef struct packed {
    bit [5:0] first;
    bit [5:0] second;
  } packed_delays_t;

  task run();
    clock_delays_t delays;
    packed_delays_t packed_delays;
    bit [5:0] scalar;
    bit io_changed;
    bit main_changed;
    bit usb_changed;
    bit packed_changed;
    bit scalar_changed;
    for (int trial = 0; trial < 8; trial++) begin
      if (!std::randomize(delays)) $fatal(1, "unpacked struct randomize failed");
      if (!std::randomize(packed_delays)) $fatal(1, "packed struct randomize failed");
      if (!std::randomize(scalar)) $fatal(1, "scalar randomize failed");
      io_changed |= delays.io_delay != 0;
      main_changed |= delays.main_delay != 0;
      usb_changed |= delays.usb_delay != 0;
      packed_changed |= packed_delays != 0;
      scalar_changed |= scalar != 0;
    end
    if (!io_changed || !main_changed || !usb_changed)
      $fatal(1, "an unpacked struct member never changed");
    if (!packed_changed) $fatal(1, "packed struct never changed");
    if (!scalar_changed) $fatal(1, "scalar never changed");
  endtask
endclass

module sv_std_randomize_unpacked_struct;
  initial begin
    clock_worker worker;
    worker = new;
    worker.run();
    $display("PASSED");
    $finish(0);
  end
endmodule
