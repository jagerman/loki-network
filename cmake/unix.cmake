if(NOT UNIX)
  return()
endif()

include(CheckCXXSourceCompiles)
include(CheckLibraryExists)

if(WITH_JEMALLOC)
  find_package(Jemalloc REQUIRED)
  if(NOT JEMALLOC_FOUND)
    message(FATAL_ERROR "did not find jemalloc")
  endif()
  add_definitions(-DUSE_JEMALLOC)
  message(STATUS "using jemalloc")
endif()

add_library(curl INTERFACE)

option(DOWNLOAD_CURL "download and statically compile in CURL" OFF)
# Allow -DDOWNLOAD_CURL=FORCE to download without even checking for a local libcurl
if(NOT DOWNLOAD_CURL STREQUAL "FORCE")
  include(FindCURL)
endif()

if(CURL_FOUND)
  message(STATUS "using system curl")
  if(TARGET CURL::libcurl) # cmake 3.12+
    target_link_libraries(curl INTERFACE CURL::libcurl)
  else()
    target_link_libraries(curl INTERFACE ${CURL_LIBRARIES})
    target_include_directories(curl INTERFACE ${CURL_INCLUDE_DIRS})
  endif()
elseif(DOWNLOAD_CURL)
  message(STATUS "libcurl not found, but DOWNLOAD_CURL specified, so downloading it")
  include(DownloadLibCurl)
  target_link_libraries(curl INTERFACE curl_vendor)
else()
  message(FATAL_ERROR "Could not find libcurl; either install it on your system or use -DDOWNLOAD_CURL=ON to download and build an internal copy")
endif()

add_definitions(-DUNIX)
add_definitions(-DPOSIX)

if (STATIC_LINK_RUNTIME OR STATIC_LINK)
  set(LIBUV_USE_STATIC ON)
endif()


option(DOWNLOAD_UV "statically compile in libuv" OFF)
# Allow -DDOWNLOAD_UV=FORCE to download without even checking for a local libuv
if(NOT DOWNLOAD_UV STREQUAL "FORCE")
  find_package(LibUV 1.28.0)
endif()
if(LibUV_FOUND)
  message(STATUS "using system libuv")
elseif(DOWNLOAD_UV)
  message(STATUS "using libuv submodule")
  set(LIBUV_ROOT ${CMAKE_SOURCE_DIR}/external/libuv)
  add_subdirectory(${LIBUV_ROOT})
  set(LIBUV_INCLUDE_DIRS ${LIBUV_ROOT}/include)
  set(LIBUV_LIBRARY uv_a)
  add_definitions(-D_LARGEFILE_SOURCE)
  add_definitions(-D_FILE_OFFSET_BITS=64)
endif()
include_directories(${LIBUV_INCLUDE_DIRS})

#find_package(LokiMQ)
#if(LokiMQ_FOUND)
#  message(STATUS "using system lokimq")
#else()
message(STATUS "using lokimq submodule")
add_subdirectory(${CMAKE_SOURCE_DIR}/external/loki-mq)
#endif()

if(EMBEDDED_CFG OR ${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  link_libatomic()
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "OpenBSD")
  add_definitions(-D_BSD_SOURCE)
  add_definitions(-D_GNU_SOURCE)
  add_definitions(-D_XOPEN_SOURCE=700)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "SunOS")
  if (LIBUV_USE_STATIC)
    link_libraries(-lkstat -lsendfile)
  endif()
endif()
