# -*- mode: CMake; tab-width: 2; indent-tabs-mode: nil; -*-

cmake_minimum_required(VERSION 3.10)

project(mc1-doom)

set(SRCS
    am_map.c
    d_items.c
    d_main.c
    d_net.c
    doomdef.c
    doomstat.c
    dstrings.c
    f_finale.c
    f_wipe.c
    g_game.c
    hu_lib.c
    hu_stuff.c
    i_main.c
    info.c
    i_system.c
    m_argv.c
    m_bbox.c
    m_cheat.c
    m_fixed.c
    m_menu.c
    m_misc.c
    m_random.c
    m_swap.c
    p_ceilng.c
    p_doors.c
    p_enemy.c
    p_floor.c
    p_inter.c
    p_lights.c
    p_map.c
    p_maputl.c
    p_mobj.c
    p_plats.c
    p_pspr.c
    p_saveg.c
    p_setup.c
    p_sight.c
    p_spec.c
    p_switch.c
    p_telept.c
    p_tick.c
    p_user.c
    r_bsp.c
    r_data.c
    r_draw.c
    r_main.c
    r_plane.c
    r_segs.c
    r_sky.c
    r_things.c
    sounds.c
    s_sound.c
    st_lib.c
    st_stuff.c
    tables.c
    wi_stuff.c
    w_wad.c
    v_video.c
    z_zone.c)

# Default resolution.
set(SCREENWIDTH 640)
set(SCREENHEIGHT 360)

# Enable sanitizers in debug builds.
if((NOT MC1) AND (CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID MATCHES "Clang"))
  list(APPEND SANITIZERS
       $<$<CONFIG:Debug>:-fsanitize=address>
       $<$<CONFIG:Debug>:-fsanitize=null>
       $<$<CONFIG:Debug>:-fsanitize=pointer-overflow>
       $<$<CONFIG:Debug>:-fsanitize=undefined>)
endif()

# More warnings.
if(CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID MATCHES "Clang")
  list(APPEND OPTS
       -pedantic
       -W
       -Wall
       -Wextra)
endif()

if(UNIX)
  list(APPEND LIBS m)
endif()

if(MC1)
  list(APPEND DEFS -DMC1)
  list(APPEND LIBS -msim)

  # Resolution for MC1.
  set(SCREENWIDTH 320)
  set(SCREENHEIGHT 180)
endif()

# Video.
if(MC1)
  list(APPEND SRCS i_video_mc1.c)
else()
  find_package(SDL2)
  if(SDL2_FOUND)
    list(APPEND SRCS i_video_sdl2.c)
    list(APPEND LIBS ${SDL2_LIBRARIES})
  else()
    set(CURSES_NEED_NCURSES TRUE)
    find_package(Curses)
    if(CURSES_FOUND)
      list(APPEND SRCS i_video_ncurses.c)
      list(APPEND LIBS ${CURSES_LIBRARIES})
    else()
      list(APPEND SRCS i_video_dummy.c)
    endif()
  endif()
endif()

# Sound.
find_package(ALSA)
if(ALSA_FOUND)
  list(APPEND SRCS i_sound_alsa.c)
  list(APPEND LIBS ${ALSA_LIBRARIES})
else()
  list(APPEND SRCS i_sound_dummy.c)
endif()

# Network.
if(UNIX)
  list(APPEND SRCS i_net.c)
else()
  list(APPEND SRCS i_net_dummy.c)
endif()

# Set the resolution.
list(APPEND DEFS
     -DSCREENWIDTH=${SCREENWIDTH}
     -DSCREENHEIGHT=${SCREENHEIGHT})

add_executable(mc1doom ${SRCS})
target_compile_definitions(mc1doom PRIVATE ${DEFS})
target_compile_options(mc1doom PRIVATE ${OPTS} ${SANITIZERS})
target_link_libraries(mc1doom PRIVATE ${LIBS} ${SANITIZERS})
set_property(TARGET mc1doom PROPERTY C_STANDARD 11)
set_property(TARGET mc1doom PROPERTY C_EXTENSIONS OFF)

# For MC1, we add a step to convert the ELF binary to a raw binary.
if(MC1)
  add_custom_command(OUTPUT mc1doom.bin
                     DEPENDS mc1doom
                     COMMAND mrisc32-elf-objcopy ARGS -O binary mc1doom mc1doom.bin
                     COMMENT "Generate raw binary")
  add_custom_target(mc1doom_raw ALL
                    DEPENDS mc1doom.bin)
endif()	

