// Typical DV transaction constraints.
class bus_txn;
  typedef enum bit [1:0] {READ, WRITE, IDLE} kind_e;
  rand kind_e kind;
  rand bit [31:0] addr;
  rand bit [7:0] len;
  rand bit [3:0] be;
  rand bit [31:0] data;
  constraint c_kind { kind dist {READ := 4, WRITE := 4, IDLE := 1}; }
  constraint c_addr { addr inside {[32'h1000:32'h1FFF], [32'h8000:32'h8FFF]}; addr[1:0] == 0; }
  constraint c_len  { len inside {[1:16]}; (kind == IDLE) -> len == 1; }
  constraint c_be   { be != 0; (len > 4) -> be == 4'hF; }
endclass
module main;
  initial begin
    bus_txn t = new;
    int nr = 0, nw = 0, ni = 0;
    longint sum = 0;
    for (int i = 0; i < 1000; i++) begin
      if (!t.randomize()) $display("FAIL");
      case (t.kind) bus_txn::READ: nr++; bus_txn::WRITE: nw++; default: ni++; endcase
      sum += t.addr + t.len + t.be;
    end
    $display("r=%0d w=%0d i=%0d sum=%0d", nr, nw, ni, sum);
  end
endmodule
