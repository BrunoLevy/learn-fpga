include ../makefile.inc

# specific options
CFLAGS:=$(CFLAGS) -Wno-strict-prototypes -Wno-missing-prototypes -Wno-old-style-definition

all: doom.elf

DOOM_OBJECTS= \
am_map.o \
d_items.o \
d_main.o \
d_net.o \
doomdef.o \
doomstat.o \
dstrings.o \
f_finale.o \
f_wipe.o \
g_game.o \
hu_lib.o \
hu_stuff.o \
i_main.o \
i_net_dummy.o \
info.o \
i_sound_dummy.o \
i_system.o \
i_video_oled.o \
m_argv.o \
m_bbox.o \
m_cheat.o \
m_fixed.o \
m_menu.o \
m_misc.o \
m_random.o \
m_swap.o \
p_ceilng.o \
p_doors.o \
p_enemy.o \
p_floor.o \
p_inter.o \
p_lights.o \
p_map.o \
p_maputl.o \
p_mobj.o \
p_plats.o \
p_pspr.o \
p_saveg.o \
p_setup.o \
p_sight.o \
p_spec.o \
p_switch.o \
p_telept.o \
p_tick.o \
p_user.o \
r_bsp.o \
r_data.o \
r_draw.o \
r_main.o \
r_plane.o \
r_segs.o \
r_sky.o \
r_things.o \
sounds.o \
s_sound.o \
st_lib.o \
st_stuff.o \
tables.o \
v_video.o \
wi_stuff.o \
w_wad.o \
z_zone.o



doom.elf: $(DOOM_OBJECTS) libliteos.a crt0.o sbrk.o exit.o
	$(CC) ./crt0.o $(DOOM_OBJECTS) sbrk.o $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-L. -lliteos $(LIBS:lib%=-l%) -lbase exit.o
	chmod -x $@

%.o: mc1-doom/src/%.c
	$(compile)
