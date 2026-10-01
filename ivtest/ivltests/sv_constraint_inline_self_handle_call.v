// Inside h.randomize() with {...}, a path through the handle being
// randomized names the target's own member (IEEE 1800-2017/2023 18.7):
// m_data_pkt.data.size() is data.size() (OpenTitan usbdev).
class data_pkt;
  rand byte unsigned data[];
  constraint c { data.size() inside {[1:8]}; }
endclass
class seq;
  data_pkt m_data_pkt = new;
  bit randomize_length;
  int num_of_bytes = 5;
  function bit go();
    return m_data_pkt.randomize() with {
      !randomize_length -> m_data_pkt.data.size() == num_of_bytes;
      m_data_pkt.data[0] == 8'h42;
    };
  endfunction
endclass
module test;
  initial begin
    automatic seq s = new;
    if (s.go() && s.m_data_pkt.data.size() == 5 && s.m_data_pkt.data[0] == 8'h42) $display("PASSED");
    else $display("FAILED %0d", s.m_data_pkt.data.size());
  end
endmodule
