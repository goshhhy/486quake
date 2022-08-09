cmake_minimum_required(VERSION 3.00)

project(quake C)
set(VERSION 0.1.0)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

include_directories(src)

add_definitions(
	-DSUBARCH="68k" 
	-DOLEVEL=""
	-DLTOFLAGS=""
	-DVERSION=""
	-DCCVERSION=""
	-DTYPE_BOOL=1
	-DREVISION="7"
	-Did386=0
	)


add_application(Quake
	../src/cl_demo.c
	../src/cl_input.c
	../src/cl_main.c
	../src/cl_parse.c
	../src/cl_tent.c
	../src/chase.c
	../src/cmd.c
	../src/common.c
	../src/console.c
	../src/crc.c
	../src/cvar.c
	../src/draw.c
	../src/d_edge.c
	../src/d_fill.c
	../src/d_init.c
	../src/d_modech.c
	../src/d_part.c
	../src/d_polyse.c
	../src/d_scan.c
	../src/d_sky.c
	../src/d_sprite.c
	../src/d_surf.c
	../src/d_vars.c
	../src/d_zpoint.c
	../src/host.c
	../src/host_cmd.c
	../src/keys.c
	../src/menu.c
	../src/mathlib.c
	../src/model.c
	../src/net_loop.c
	../src/net_main.c
	../src/net_vcr.c
	../src/nonintel.c
	../src/pr_cmds.c
	../src/pr_edict.c
	../src/pr_exec.c
	../src/r_aclip.c
	../src/r_alias.c
	../src/r_bsp.c
	../src/r_light.c
	../src/r_draw.c
	../src/r_efrag.c
	../src/r_edge.c
	../src/r_misc.c
	../src/r_main.c
	../src/r_sky.c
	../src/r_sprite.c
	../src/r_surf.c
	../src/r_part.c
	../src/r_vars.c
	../src/screen.c
	../src/sbar.c
	../src/sv_main.c
	../src/sv_phys.c
	../src/sv_move.c
	../src/sv_user.c
	../src/zone.c	
	../src/view.c	
	../src/wad.c
	../src/world.c

    ../src/sys_mac.c
    ../src/net_none.c
    ../src/in_null.c
	../src/snd_null.c
    ../src/cd_null.c
    ../src/vid_null.c
    )

target_link_libraries(Quake m)
