cmake_minimum_required(VERSION 3.22)
project(mylib LANGUAGES CXX)

add_library(mylib SHARED mylib.cpp)

set_target_properties(mylib PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        POSITION_INDEPENDENT_CODE ON
        OUTPUT_NAME "mylib"          # -> libmylib.so
)

target_compile_definitions(mylib PRIVATE ANDROID)
target_compile_options(mylib PRIVATE -O2 -fPIC -fvisibility=hidden)

if(ANDROID AND (ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "x86_64"))
    target_link_options(mylib PRIVATE -Wl,-z,max-page-size=16384)
endif()

# Link android log nếu cần
find_library(log-lib log)
if(log-lib)
    target_link_libraries(mylib ${log-lib})
endif()