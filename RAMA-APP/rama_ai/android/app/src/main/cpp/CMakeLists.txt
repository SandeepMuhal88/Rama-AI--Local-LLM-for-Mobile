cmake_minimum_required(VERSION 3.10)

project(rama_ai)

set(CMAKE_CXX_STANDARD 17)

add_subdirectory(llama.cpp)

add_library(
    llama_lib
    SHARED
    wrapper.cpp
)

target_link_libraries(
    llama_lib
    llama
    log
)