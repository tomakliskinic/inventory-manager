cmake_minimum_required(VERSION 3.16)

project(inventoryManager VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Sql)

qt_standard_project_setup(REQUIRES 6.10)

qt_add_executable(appinventoryManager
    main.cpp
)

qt_add_qml_module(appinventoryManager
    URI inventoryManager
    QML_FILES
        Main.qml
    SOURCES
        enums.h
        databasemanager.h databasemanager.cpp
)

qt_add_resources(appinventoryManager "sql_resources"
    PREFIX "/sql"
    BASE "database/sql"
    FILES
        database/sql/00_full_schema.sql
        database/sql/seed_01_weapons.sql
        database/sql/seed_02_armor.sql
        database/sql/seed_03_gear.sql
        database/sql/seed_04_tools.sql
        database/sql/seed_05_magic.sql
    )

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appinventoryManager PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appinventoryManager
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appinventoryManager
    PRIVATE Qt6::Quick Qt6::Sql
)

install(TARGETS appinventoryManager
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
