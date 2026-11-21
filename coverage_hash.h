#ifndef IVL_COVERAGE_HASH_H
#define IVL_COVERAGE_HASH_H

# include <cstddef>
# include <cstdint>
# include <string>

// FNV-1a over bytes. Fixed-width hex is independent of locale and word size.
class coverage_hash {
    public:
      void add(const char*data, std::size_t size)
      {
	    for (std::size_t i = 0; i < size; ++i) {
		  value_ ^= static_cast<unsigned char>(data[i]);
		  value_ *= UINT64_C(1099511628211);
	    }
      }

      void field(const std::string&value)
      {
	    const std::string size = std::to_string(value.size()) + ':';
	    add(size.data(), size.size());
	    add(value.data(), value.size());
      }

      void field(const char*value) { field(std::string(value ? value : "")); }

      std::string hex() const
      {
	    static const char digits[] = "0123456789abcdef";
	    std::string result(16, '0');
	    for (unsigned i = 0; i < 16; ++i)
		  result[15 - i] = digits[(value_ >> (4 * i)) & 15];
	    return result;
      }

    private:
      uint64_t value_ = UINT64_C(14695981039346656037);
};

#endif
