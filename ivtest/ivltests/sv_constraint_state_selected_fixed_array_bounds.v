// IEEE 1800-2017 7.4.6; IEEE 1800-2023 7.4.5; both editions 18.3 and 18.5.
class state_selected_high_bound;
  longint selector;
  bit [7:0] values[64'sh100000001:64'sh100000000];
  rand bit witness;

  constraint selected_read { values[selector] == 8'ha5; witness == 1; }
endclass

class state_selected_negative_bound;
  longint selector;
  bit [7:0] values[-1:-2];
  rand bit witness;

  constraint selected_read { values[selector] == 8'h3c; witness == 1; }
endclass

class state_selected_unsigned_oob;
  bit [63:0] selector;
  bit [7:0] values[-1:-2];
  rand bit witness;

  constraint invalid_read { values[selector] == 8'h00; witness == 1; }
endclass

class state_selected_unsigned_constant_oob;
  bit [7:0] values[-1:-2];
  rand bit witness;

  constraint invalid_read {
    values[64'hffffffffffffffff] == 8'h00;
    witness == 1;
  }
endclass

module test;
  state_selected_high_bound high;
  state_selected_negative_bound negative;
  state_selected_unsigned_oob unsigned_oob;
  state_selected_unsigned_constant_oob unsigned_constant_oob;

  initial begin
    high = new;
    high.values[64'sh100000000] = 8'ha5;
    high.values[64'sh100000001] = 8'h5a;
    if (high.values[64'sh100000000] != 8'ha5
        || high.values[64'sh100000001] != 8'h5a)
      $fatal(1, "ordinary high-bound array read disagrees with declaration");
    high.selector = 64'sh100000000;
    if (high.values[high.selector] != 8'ha5)
      $fatal(1, "ordinary dynamic high-bound selector lost upper index bits");
    if (!high.randomize() || high.witness != 1)
      $fatal(1, "64-bit high declared bound lost upper index bits");

    negative = new;
    negative.values[-1] = 8'h3c;
    negative.values[-2] = 8'hc3;
    if (negative.values[-1] != 8'h3c || negative.values[-2] != 8'hc3)
      $fatal(1, "ordinary negative-bound array read disagrees with declaration");
    negative.selector = -1;
    if (negative.values[negative.selector] != 8'h3c)
      $fatal(1, "ordinary dynamic signed selector missed negative index");
    if (!negative.randomize() || negative.witness != 1)
      $fatal(1, "signed negative selector did not match declared index");

    unsigned_oob = new;
    unsigned_oob.values[-1] = 8'h7e;
    unsigned_oob.values[-2] = 8'he7;
    if (unsigned_oob.values[-1] != 8'h7e
        || unsigned_oob.values[-2] != 8'he7)
      $fatal(1, "ordinary unsigned-control source array read failed");
    unsigned_oob.selector = 64'hffffffffffffffff;
    if (unsigned_oob.values[unsigned_oob.selector] !== 8'h00)
      $fatal(1, "ordinary dynamic unsigned MAX aliased signed -1");
    if (!unsigned_oob.randomize() || unsigned_oob.witness != 1)
      $fatal(1, "unsigned max aliased signed -1 instead of using OOB zero");

    unsigned_constant_oob = new;
    unsigned_constant_oob.values[-1] = 8'h7e;
    unsigned_constant_oob.values[-2] = 8'he7;
    if (unsigned_constant_oob.values[-1] != 8'h7e
        || unsigned_constant_oob.values[-2] != 8'he7)
      $fatal(1, "ordinary constant-OOB source array read failed");
    if (!unsigned_constant_oob.randomize()
        || unsigned_constant_oob.witness != 1)
      $fatal(1, "constant unsigned MAX aliased signed -1");

    $display("PASSED");
  end
endmodule
