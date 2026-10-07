cmake_minimum_required(VERSION 3.22)
project(ChotkiLinux LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Test)
qt_standard_project_setup()
if(Qt6_VERSION VERSION_GREATER_EQUAL 6.8)
    qt_policy(SET QTP0001 NEW)
endif()

qt_add_executable(chotki-linux main.cpp Bridge.cpp Bridge.h)
qt_add_qml_module(chotki-linux
    URI ChotkiLinux
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES Main.qml
    RESOURCES fonts/XCharter-Roman.otf fonts/XCharter-Bold.otf
)
target_link_libraries(chotki-linux PRIVATE Qt6::Quick Qt6::Network)

enable_testing()
add_executable(chotki-navigation-test tests/NavigationTest.cpp)
target_link_libraries(chotki-navigation-test PRIVATE Qt6::Quick Qt6::Test)
target_compile_definitions(chotki-navigation-test PRIVATE CHOTKI_QML_SOURCE="${CMAKE_CURRENT_SOURCE_DIR}/Main.qml")
add_test(NAME sidebar-navigation COMMAND chotki-navigation-test)
set_tests_properties(sidebar-navigation PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
