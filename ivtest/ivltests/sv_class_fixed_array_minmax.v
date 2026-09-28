// IEEE 1800-2017/2023 7.12.1: min/max on a fixed unpacked-array class
// property returns a queue of the same element type. The property receiver
// must be read once, including when its base expression has side effects.
class fixed_minmax_holder;
  logic signed [7:0] values[4:1];
  bit [31:0] timers[4];
endclass

module main;
  fixed_minmax_holder holder;
  logic signed [7:0] result[$];
  logic signed [7:0] direct[4:1];
  bit [31:0] timer_result[$];
  int receiver_calls;

  function fixed_minmax_holder get_holder;
    receiver_calls++;
    return holder;
  endfunction

  initial begin
    holder = new;
    holder.values[4] = -8'sd8;
    holder.values[3] = 8'sd30;
    holder.values[2] = -8'sd100;
    holder.values[1] = 8'sd30;
    direct[4] = holder.values[4];
    direct[3] = holder.values[3];
    direct[2] = holder.values[2];
    direct[1] = holder.values[1];
    holder.timers = '{8, 16, 3, 12};

    timer_result = holder.timers.max();
    if (timer_result.size() != 1 || timer_result[0] !== 32'd16)
      $fatal(1, "OpenTitan-shaped fixed property max failed");

    result = holder.values.max();
    if (result.size() != 1 || result[0] !== 8'sd30)
      $fatal(1, "fixed property max failed");

    result = holder.values.min();
    if (result.size() != 1 || result[0] !== -8'sd100)
      $fatal(1, "fixed property min failed");

    result = get_holder().values.max();
    if (receiver_calls != 1 || result.size() != 1
        || result[0] !== 8'sd30)
      $fatal(1, "fixed property receiver was not evaluated once");

    result = holder.values.max(value)
             with (value.index() == 4 ? 8'sd100 : value);
    if (result.size() != 1 || result[0] !== -8'sd8)
      $fatal(1, "fixed property max used an ordinal index");

    result = holder.values.min(value)
             with (value.index() == 1 ? -8'sd120 : value);
    if (result.size() != 1 || result[0] !== 8'sd30)
      $fatal(1, "fixed property min used an ordinal index");

    result = direct.max(value)
             with (value.index() == 4 ? 8'sd100 : value);
    if (result.size() != 1 || result[0] !== -8'sd8)
      $fatal(1, "direct fixed max used an ordinal index");

    $display("PASSED");
  end
endmodule
