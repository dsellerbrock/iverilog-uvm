// Native legacy recording lifecycle. Included by the Icarus DPI umbrella.
// Attribute capture is separate: these entry points never fabricate attributes.
#include <map>
#include <string>
#include <cstdio>
#include <climits>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

namespace {
struct recording_owner {
      FILE* file;
      bool poisoned;
      int text_fd;
      FILE* text_file;
};
struct recording_handle {
      int owner;
      bool stream;
      bool ended;
};
static std::map<int, recording_owner> recording_owners;
static std::map<int, recording_handle> recording_handles;
static int recording_next_owner = 1;
static bool recording_cleanup_registered = false;

static int recording_error(const char*message)
{
      vpi_printf("IVL_UVM_RECORD_ERROR: %s\n", message);
      return 0;
}

static std::string recording_quote(const char*value)
{
      // Lifecycle names are DPI strings. Escape bytes, not locale characters.
      static const char hex[] = "0123456789abcdef";
      std::string result = "\"";
      for (const unsigned char*p = reinterpret_cast<const unsigned char*>(value);
           p && *p; ++p) {
            if (*p == '\"' || *p == '\\') {
                  result += '\\'; result += *p;
            } else if (*p < 32 || *p >= 127) {
                  result += "\\u00";
                  result += hex[*p >> 4]; result += hex[*p & 15];
            } else result += *p;
      }
      return result + '\"';
}

static recording_owner* recording_get_owner(int owner)
{
      auto found = recording_owners.find(owner);
      if (found == recording_owners.end() || found->second.poisoned) {
            recording_error("unknown or failed recorder owner");
            return nullptr;
      }
      return &found->second;
}

static bool recording_write(int owner, const char*event,
                            const std::string&fields = "")
{
      recording_owner*dest = recording_get_owner(owner);
      if (!dest) return false;
      s_vpi_time now = {};
      now.type = vpiSimTime;
      vpi_get_time(nullptr, &now);
      unsigned long long tick = (static_cast<unsigned long long>(now.high) << 32)
                              | now.low;
      std::string row = "{\"event\":" + recording_quote(event)
            + ",\"owner\":" + std::to_string(owner)
            + ",\"tick\":\"" + std::to_string(tick) + "\"" + fields + "}\n";
      if (fwrite(row.data(), 1, row.size(), dest->file) != row.size()
          || fflush(dest->file) != 0) {
            dest->poisoned = true;
            recording_error("journal write/flush failed; recorder is poisoned");
            return false;
      }
      return true;
}

static PLI_INT32 recording_cleanup(p_cb_data)
{
      for (auto&entry : recording_owners) {
            if (entry.second.text_fd) {
                  FILE*text = vpi_get_file(entry.second.text_fd);
                  if (text != entry.second.text_file || ferror(text)
                      || fflush(text) != 0) {
                        recording_error("legacy text output failed at cleanup");
                        entry.second.poisoned = true;
                  }
                  if (text == entry.second.text_file
                      && vpi_mcd_close(entry.second.text_fd) != 0) {
                        recording_error("legacy text close failed");
                        entry.second.poisoned = true;
                  }
            }
            if (entry.second.poisoned || !recording_write(entry.first, "close"))
                  vpip_set_return_value(1);
            if (fclose(entry.second.file) != 0) {
                  recording_error("journal close failed");
                  vpip_set_return_value(1);
            }
      }
      recording_handles.clear();
      recording_owners.clear();
      recording_next_owner = 1;
      recording_cleanup_registered = false;
      return 0;
}

static bool recording_new_handle(int owner, int handle)
{
      if (!recording_get_owner(owner)) return false;
      if (handle <= 0 || recording_handles.count(handle)) {
            recording_error("invalid or already registered handle");
            return false;
      }
      return true;
}

static recording_handle* recording_get_handle(int owner, int handle,
                                               bool transaction_only)
{
      if (!recording_get_owner(owner)) return nullptr;
      auto found = recording_handles.find(handle);
      if (found == recording_handles.end() || found->second.owner != owner
          || (transaction_only && found->second.stream)) {
            recording_error("unknown, wrong-owner or wrong-kind handle");
            return nullptr;
      }
      return &found->second;
}
}

extern "C" int ivl_uvm_record_open(const char*filename)
{
      if (!filename || !*filename || recording_next_owner == INT_MAX)
            return recording_error("invalid journal name or exhausted owner IDs");
      if (!recording_cleanup_registered) {
            s_cb_data cb = {};
            cb.reason = cbEndOfSimulation;
            cb.cb_rtn = recording_cleanup;
            if (!vpi_register_cb(&cb))
                  return recording_error("cannot register recording cleanup");
            recording_cleanup_registered = true;
      }
      // Atomic exclusive creation also rejects existing symlink/hardlink aliases.
      int fd = open(filename, O_WRONLY | O_CREAT | O_EXCL, 0666);
      if (fd < 0) return recording_error("cannot exclusively create journal");
      FILE*file = fdopen(fd, "w");
      if (!file) {
            close(fd);
            // Preserve the failed creation as evidence; never unlink a path
            // that another process could have replaced after exclusive open.
            return recording_error("cannot open journal stream");
      }
      int owner = recording_next_owner++;
      recording_owners.emplace(owner, recording_owner{file, false, 0, nullptr});
      if (!recording_write(owner, "open")) return 0;
      return owner;
}

extern "C" int ivl_uvm_record_open_text(int owner, const char*filename)
{
      recording_owner*dest = recording_get_owner(owner);
      if (!dest) return 0;
      if (!filename || !*filename || dest->text_fd)
            return recording_error("invalid or already open legacy text log");
      // Keep the exclusively created file open in the simulator's FD table.
      // The superclass writes this descriptor; it never reopens the pathname.
      int fd = vpi_fopen(filename, "wx");
      if (!fd) return recording_error("cannot exclusively create legacy text log");
      dest->text_fd = fd;
      dest->text_file = vpi_get_file(fd);
      if (!recording_write(owner, "legacy_file", ",\"path\":" + recording_quote(filename)))
            return 0;
      return fd;
}

extern "C" int ivl_uvm_record_check_text(int owner, int fd)
{
      recording_owner*dest = recording_get_owner(owner);
      if (!dest) return 0;
      if (!fd || fd != dest->text_fd || vpi_get_file(fd) != dest->text_file
          || ferror(dest->text_file) || fflush(dest->text_file) != 0) {
            dest->poisoned = true;
            return recording_error("legacy text descriptor or output failed");
      }
      return 1;
}

extern "C" int ivl_uvm_record_stream(int owner, int handle, const char*name,
                                      const char*type, const char*scope)
{
      if (!recording_new_handle(owner, handle)) return 0;
      if (!recording_write(owner, "stream", ",\"handle\":" + std::to_string(handle)
            + ",\"name\":" + recording_quote(name) + ",\"type\":" + recording_quote(type)
            + ",\"scope\":" + recording_quote(scope))) return 0;
      recording_handles.emplace(handle, recording_handle{owner, true, false});
      return 1;
}

extern "C" int ivl_uvm_record_begin(int owner, int handle, int stream,
      const char*type, const char*name, const char*label, const char*description,
      unsigned long long begin_time)
{
      if (!recording_new_handle(owner, handle)) return 0;
      recording_handle*parent = recording_get_handle(owner, stream, false);
      if (!parent || !parent->stream) return recording_error("begin requires an owned stream");
      if (!recording_write(owner, "begin", ",\"handle\":" + std::to_string(handle)
            + ",\"stream\":" + std::to_string(stream)
            + ",\"type\":" + recording_quote(type) + ",\"name\":" + recording_quote(name)
            + ",\"label\":" + recording_quote(label)
            + ",\"description\":" + recording_quote(description)
            + ",\"begin_time\":\"" + std::to_string(begin_time) + "\"")) return 0;
      recording_handles.emplace(handle, recording_handle{owner, false, false});
      return 1;
}

extern "C" int ivl_uvm_record_kind(int owner, int handle, const char*kind)
{
      auto found = recording_handles.find(handle);
      if (found == recording_handles.end() || !kind) return 0;
      auto dest = recording_owners.find(found->second.owner);
      if (dest == recording_owners.end() || dest->second.poisoned) return 0;
      const recording_handle&h = found->second;
      if (std::string(kind) == "Fiber") return h.stream && h.owner == owner;
      if (std::string(kind) == "Transaction") return !h.stream;
      return 0;
}

extern "C" int ivl_uvm_record_link(int owner, int left, int right,
                                   const char*relation)
{
      if (!recording_get_owner(owner)) return 0;
      if (!ivl_uvm_record_kind(owner, left, "Transaction")
          || !ivl_uvm_record_kind(owner, right, "Transaction"))
            return recording_error("link requires two registered transactions");
      // Child links may be issued by the right endpoint's recorder. Neither
      // endpoint is rebound; the issuing journal records both actual owners.
      return recording_write(owner, "link", ",\"left\":" + std::to_string(left)
            + ",\"right\":" + std::to_string(right)
            + ",\"left_owner\":" + std::to_string(recording_handles.at(left).owner)
            + ",\"right_owner\":" + std::to_string(recording_handles.at(right).owner)
            + ",\"relation\":" + recording_quote(relation));
}

extern "C" int ivl_uvm_record_end(int owner, int handle, unsigned long long end_time)
{
      recording_handle*h = recording_get_handle(owner, handle, true);
      if (!h) return 0;
      if (h->ended) return recording_error("transaction already ended");
      if (!recording_write(owner, "end", ",\"handle\":" + std::to_string(handle)
            + ",\"end_time\":\"" + std::to_string(end_time) + "\"")) return 0;
      h->ended = true;
      return 1;
}

extern "C" int ivl_uvm_record_free(int owner, int handle)
{
      if (!recording_get_handle(owner, handle, false)) return 0;
      // The legacy API permits freeing a live transaction or stream.
      if (!recording_write(owner, "free", ",\"handle\":" + std::to_string(handle))) return 0;
      recording_handles.erase(handle);
      return 1;
}

// U15 registration smoke test (design-facts-20260911.md, ACTIVE_WORK U15).
// This calltf does not yet encode or journal a value; it only proves the
// systf resolves under the real -uvm loading path and reads back the
// argument kind vpi_get_value(vpiObjTypeVal) would dispatch on. The lossless
// packed/real/string encoder is a separate, not-yet-implemented step.
namespace {
PLI_INT32 record_attribute_smoke_calltf(PLI_BYTE8*)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle harg = vpi_scan(args);
      vpiHandle narg = vpi_scan(args);
      vpiHandle varg = vpi_scan(args);
      if (!harg || !narg || !varg) {
            recording_error("$ivl_uvm_record_attribute requires (handle, name, value)");
            if (args) vpi_free_object(args);
            return 0;
      }
      s_vpi_value hv; hv.format = vpiIntVal;
      vpi_get_value(harg, &hv);
      s_vpi_value nv; nv.format = vpiStringVal;
      vpi_get_value(narg, &nv);
      // 38.15: vpi_get_value's string buffer "is overwritten with each
      // call... If the value is needed, it should be saved by the
      // application." Confirmed empirically here: Icarus's vpiVectorVal and
      // vpiStringVal formats share the same need_result_buf(RBUF_VAL) pool
      // (vvp/vpi_const.cc), so ANY next vpi_get_value call -- not only a
      // second string read -- can invalidate this pointer. Copy immediately.
      std::string name = nv.value.str ? nv.value.str : "";
      s_vpi_value vv; vv.format = vpiObjTypeVal;
      vpi_get_value(varg, &vv);
      auto found = recording_handles.find((int)hv.value.integer);
      int known_owner = found == recording_handles.end() ? 0 : found->second.owner;
      vpi_printf("IVL_UVM_RECORD_ATTRIBUTE_SMOKE: handle=%d owner=%d name=%s objfmt=%d\n",
                 (int)hv.value.integer, known_owner, name.c_str(), (int)vv.format);
      vpi_free_object(args);
      return 0;
}
}

extern "C" void ivl_uvm_record_register_systf(void)
{
      s_vpi_systf_data data = {};
      data.type = vpiSysTask;
      data.tfname = "$ivl_uvm_record_attribute";
      data.calltf = record_attribute_smoke_calltf;
      vpi_register_systf(&data);
}
