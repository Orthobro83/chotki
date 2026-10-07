cmake_minimum_required(VERSION 3.22)
project(ChotkiLinuxSpike LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)
qt_standard_project_setup()

qt_add_executable(chotki-linux-spike main.cpp Bridge.cpp Bridge.h)
qt_add_qml_module(chotki-linux-spike
    URI ChotkiSpike
    VERSION 1.0
    QML_FILES Main.qml
)
target_link_libraries(chotki-linux-spike PRIVATE Qt6::Quick)
