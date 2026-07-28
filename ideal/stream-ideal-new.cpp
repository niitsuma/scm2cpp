// The intended output for delayed streams, rewritten from the 2011
// stream-ideal.hpp in terms of the nominal recursive type stream_cell. In
// 2011 the return type was to be obtained through decltype applied to the
// function itself, which cannot be defined; naming the type avoids that.
#include <iostream>
#include "scm2cpp.hpp"

using scm2cpp::stream_cell;

int stream_car(const stream_cell<int>& s) { return scm2cpp::car(s); }

stream_cell<int> stream_cdr(const stream_cell<int>& s) { return force(scm2cpp::cdr(s)); }

stream_cell<int> integers_starting_from(int n_int);

int stream_ref(stream_cell<int> s, int n_int)
{
    if (n_int == 0) return stream_car(s);
    else return stream_ref(stream_cdr(s), n_int - 1);
}

stream_cell<int> integers_starting_from(int n_int)
{
    return scm2cpp::make_stream(n_int, [=]() { return integers_starting_from(n_int + 1); });
}

int main()
{
    auto integers = integers_starting_from(1);
    std::cout << stream_ref(integers, 10) << std::endl;
    return 0;
}
