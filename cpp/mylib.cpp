#include <cstdint>

extern "C" __attribute__((visibility("default")))
int addInts(int a, int b) {
    return a + b;
}