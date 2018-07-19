#include "fuzzutil.h"

#include <cstring>
#include <utility>

contrib::optional<two_inputs> SplitInputs(const uint8_t *Data, size_t Size)
{
	if (!Size) {
		return contrib::nullopt;
	}
	// figure out a random point in [0, Size] to split our input.
	size_t left_size = (Data[0] / 255.0) * (Size - 1);

	// Copy inputs to new allocations so if bdiff over-reads
	// AddressSanitizer can detect it.
	std::unique_ptr<char[]> left(new char[left_size]);
	std::memcpy(left.get(), Data + 1, left_size);
	// right starts at the next byte after left ends
	size_t right_size = Size - (left_size + 1);
	std::unique_ptr<char[]> right(new char[right_size]);
	std::memcpy(right.get(), Data + 1 + left_size, right_size);
	LOG(2) << "inputs are  " << left_size << " and " << right_size
	       << " bytes" << std::endl;
	two_inputs result = {std::move(right), right_size, std::move(left),
	                     left_size};
	return result;
}
