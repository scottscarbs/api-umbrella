set(PACKAGE_VERSION_ITERATION 1)

file(STRINGS ${CMAKE_SOURCE_DIR}/src/api-umbrella/version.txt VERSION_STRING)
string(REGEX MATCH "^([^-]+)" PACKAGE_VERSION ${VERSION_STRING})
string(REGEX MATCH "-(.+)$" VERSION_PRE ${VERSION_STRING})
if(VERSION_PRE)
  string(REGEX REPLACE "^-" "" VERSION_PRE ${VERSION_PRE})
  set(PACKAGE_VERSION_ITERATION 0.${PACKAGE_VERSION_ITERATION}.${VERSION_PRE})
endif()

if(EXISTS "/etc/redhat-release")
  set(PACKAGE_TYPE rpm)

  execute_process(
    COMMAND rpm --query centos-release
    OUTPUT_VARIABLE RPM_DIST
  )
  STRING(REGEX MATCH "el[0-9]+" RPM_DIST ${RPM_DIST})
elseif(EXISTS "/etc/debian_version")
  set(PACKAGE_TYPE deb)

  execute_process(
    COMMAND lsb_release --codename --short
    OUTPUT_VARIABLE RELEASE_NAME
  )

  set(PACKAGE_VERSION_ITERATION "${PACKAGE_VERSION_ITERATION}~${RELEASE_NAME}")
else()
  message(FATAL_ERROR "Unknown build system")
endif()

add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/Gemfile ${CMAKE_SOURCE_DIR}/build/package/Gemfile.lock bundler
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/package
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --clean --path=${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
)

set(FPM_ARGS)
list(APPEND FPM_ARGS -t ${PACKAGE_TYPE})
list(APPEND FPM_ARGS -s dir)
list(APPEND FPM_ARGS -C ${WORK_DIR}/package-dest-core)
list(APPEND FPM_ARGS --verbose)
list(APPEND FPM_ARGS --name api-umbrella)
list(APPEND FPM_ARGS --license MIT)
list(APPEND FPM_ARGS --url https://apiumbrella.io)
list(APPEND FPM_ARGS --version ${PACKAGE_VERSION})
list(APPEND FPM_ARGS --iteration ${PACKAGE_VERSION_ITERATION})
list(APPEND FPM_ARGS --config-files etc/api-umbrella/api-umbrella.yml)
list(APPEND FPM_ARGS --after-install ${CMAKE_SOURCE_DIR}/build/package/scripts/after-install)
list(APPEND FPM_ARGS --before-remove ${CMAKE_SOURCE_DIR}/build/package/scripts/before-remove)
list(APPEND FPM_ARGS --after-remove ${CMAKE_SOURCE_DIR}/build/package/scripts/after-remove)
list(APPEND FPM_ARGS --directories /etc/api-umbrella)
list(APPEND FPM_ARGS --directories /opt/api-umbrella)
foreach(DEP IN LISTS CORE_PACKAGE_DEPENDENCIES)
  list(APPEND FPM_ARGS --depends ${DEP})
endforeach()
if(PACKAGE_TYPE STREQUAL rpm)
  list(APPEND FPM_ARGS --rpm-dist ${RPM_DIST})
  list(APPEND FPM_ARGS --rpm-compression xz)
elseif(PACKAGE_TYPE STREQUAL deb)
  list(APPEND FPM_ARGS --deb-compression xz)
  list(APPEND FPM_ARGS --deb-no-default-config-files)
endif()

add_custom_target(
  package-core
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
  COMMAND make
  COMMAND make install-core DESTDIR=${WORK_DIR}/package-dest-core
  COMMAND mkdir -p ${WORK_DIR}/packages
  COMMAND cd ${WORK_DIR}/packages && env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile XZ_OPT=-9 bundle exec fpm ${FPM_ARGS} .
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
)

set(FPM_ARGS)
list(APPEND FPM_ARGS -t ${PACKAGE_TYPE})
list(APPEND FPM_ARGS -s dir)
list(APPEND FPM_ARGS -C ${WORK_DIR}/package-dest-hadoop-analytics)
list(APPEND FPM_ARGS --verbose)
list(APPEND FPM_ARGS --name api-umbrella-hadoop-analytics)
list(APPEND FPM_ARGS --license MIT)
list(APPEND FPM_ARGS --url https://apiumbrella.io)
list(APPEND FPM_ARGS --version ${PACKAGE_VERSION})
list(APPEND FPM_ARGS --iteration ${PACKAGE_VERSION_ITERATION})
list(APPEND FPM_ARGS --directories /opt/api-umbrella)
list(APPEND FPM_ARGS --depends api-umbrella)
foreach(DEP IN LISTS HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES)
  list(APPEND FPM_ARGS --depends ${DEP})
endforeach()
if(PACKAGE_TYPE STREQUAL rpm)
  list(APPEND FPM_ARGS --rpm-dist ${RPM_DIST})
  list(APPEND FPM_ARGS --rpm-compression xz)
elseif(PACKAGE_TYPE STREQUAL deb)
  list(APPEND FPM_ARGS --deb-compression xz)
  list(APPEND FPM_ARGS --deb-no-default-config-files)
endif()

add_custom_target(
  package-hadoop-analytics
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND make
  COMMAND make install-hadoop-analytics DESTDIR=${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND mkdir -p ${WORK_DIR}/packages
  COMMAND cd ${WORK_DIR}/packages && env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile XZ_OPT=-9 bundle exec fpm ${FPM_ARGS} .
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
)

# CMake policy CMP0037 to allow target named "test".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  package
  COMMAND ${CMAKE_BUILD_TOOL} package-core
  COMMAND ${CMAKE_BUILD_TOOL} package-hadoop-analytics
)
cmake_policy(POP)
