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
      recording_owners.emplace(owner, recording_owner{file, false});
      if (!recording_write(owner, "open")) return 0;
      return owner;
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
