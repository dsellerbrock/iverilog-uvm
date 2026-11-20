// IEEE 1800-2017/2023 9.4.2: a struct member event tracks its singular value.
module issue3913_struct_member_events;
  class token;
    int value;
  endclass

  typedef struct { logic b; bit spare; } inner_t;
  typedef struct {
    logic b;
    bit spare;
    logic [3:0] bits;
    real r;
    string s;
    inner_t inner;
    token h;
  } state_t;
  state_t st, replacement;
  inner_t inner_replacement;
  token first, second;
  logic ordinary = 0;
  int payload = 42;
  int captured = 0;
  int checks = 0;

  task automatic check_time(input int expected, input string name);
    if ($time != expected)
      $fatal(1, "%s woke at %0t, expected %0d", name, $time, expected);
    checks++;
  endtask

  task automatic watch_ref(ref logic arg);
    @(arg) check_time(2, "ref member");
    @(arg) check_time(13, "ref member after whole replacement");
  endtask

  task automatic change_string(ref string arg);
    arg = "third";
  endtask

  typedef struct { real r; token h; bit spare; } local_t;
  task automatic concurrent_watch(input int when_changed);
    local_t local_st;
    // Distinct held NaNs expose an accidentally shared projection history.
    local_st.r = $bitstoreal(64'h7ff8000000000000 + when_changed);
    local_st.h = new;
    local_st.h.value = when_changed;
    local_st.spare = 0;
    fork
      begin @(local_st.r); check_time(when_changed, "automatic real"); end
      begin @(local_st.h); check_time(when_changed, "automatic handle"); end
      begin
        #1 local_st.spare = 1;
        #(when_changed - 1);
        local_st.r = when_changed;
        local_st.h = null;
      end
    join
  endtask

  initial begin
    first = new;
    first.value = 0;
    second = new;
    second.value = 7;
    st.b = 0;
    st.spare = 0;
    st.bits = 0;
    st.r = 1.25;
    st.s = "first";
    st.inner.b = 0;
    st.inner.spare = 0;
    st.h = first;
    inner_replacement = st.inner;
    inner_replacement.b = 1;

    fork
      begin @(st.b); check_time(2, "direct logic"); end
      begin
        @(st.r) check_time(4, "real");
        @(st.r) check_time(6, "real to NaN");
        @(st.r) check_time(10, "real from held NaN");
        @(st.r) check_time(13, "real after signed zero replacement");
      end
      begin
        @(st.s) check_time(5, "string");
        @(st.s) check_time(12, "string written through ref");
      end
      begin
        @(st.inner.b) check_time(8, "nested replacement");
        @(st.inner.b) check_time(11, "whole replacement");
      end
      begin @(st.h); check_time(11, "handle identity"); end
      begin @(st.inner.b or ordinary); check_time(1, "ordinary or arm"); end
      begin @(st.bits[3:2] & 2'b01); check_time(7, "selected operand"); end
      begin @(st.r > 2.0); check_time(4, "real comparison operand"); end
      begin @(posedge st.bits); check_time(9, "LSB 0 to X"); end
      begin @(negedge st.b); check_time(13, "same-slot NBA pulse"); end
      watch_ref(st.b);
      concurrent_watch(3);
      concurrent_watch(9);
    join_none

    #1 ordinary = 1;
    #0 st.spare = 1;
    #1 st.b = 1;
    #1 begin
      st.r = 1.25;
      st.s = "first";
      st.h = first;
      first.value = 7;
    end
    #1 st.r = 2.5;
    #1 st.s = "second";
    #1 st.r = $bitstoreal(64'h7ff8000000000001);
    #1 begin
      replacement = st;
      replacement.bits[2] = 1;
      st = replacement;
    end
    #1 st.inner = inner_replacement;
    #1 st.bits[0] = 1'bx;
    #1 st.r = $bitstoreal(64'h8000000000000000);
    #1 begin
      replacement = st;
      replacement.inner.b = 0;
      replacement.r = 0.0;
      replacement.h = second;
      st = replacement;
    end
    #1 change_string(st.s);
    #1 begin
      st.r = 3.0;
      st.b <= 0;
      st.b <= 1;
    end
    #1 begin
      if (checks != 21 || captured != 42 || st.b !== 1)
        $fatal(1, "checks=%0d, captured=%0d, b=%b", checks, captured, st.b);
      $display("PASSED");
    end
  end

  initial begin
    #12 captured <= @(negedge st.b) payload;
    payload = 99;
  end

  initial #16 $finish(0);
endmodule
