#ifndef CONTRIB_FUZZ_FUZZUTIL_H
#define CONTRIB_FUZZ_FUZZUTIL_H
#include <iostream>
#include <memory>
#include <optional>
#include <stdint.h>

/* set DEBUG to 1 for a few debugging prints, or 2 for a lot */
#define DEBUG 0
#define LOG(level)                                                             \
	if (level <= DEBUG)                                                    \
	std::cout

struct two_inputs {
	std::unique_ptr<char[]> right;
	size_t right_size;
	std::unique_ptr<char[]> left;
	size_t left_size;
};

/* Split a non-zero-length input into two inputs. */
std::optional<two_inputs> SplitInputs(const uint8_t *Data, size_t Size);

#endif /* CONTRIB_FUZZ_FUZZUTIL_H */
