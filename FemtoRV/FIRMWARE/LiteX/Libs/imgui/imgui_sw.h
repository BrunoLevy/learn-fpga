// By Emil Ernerfeldt 2018
// LICENSE:
//   This software is dual-licensed to the public domain and under the following
//   license: you are granted a perpetual, irrevocable license to copy, modify,
//   publish, and distribute this file as you see fit.
// WHAT:
//   This is a software renderer for Dear ImGui.
//   It is decently fast, but has a lot of room for optimization.
//   The goal was to get something fast and decently accurate in not too many lines of code.
// LIMITATIONS:
//   * It is not pixel-perfect, but it is good enough for must use cases.
//   * It does not support painting with any other texture than the default font texture.
#pragma once

#include <stdint.h>

namespace imgui_sw {

struct SwOptions
{
	bool optimize_text = true;  // No reason to turn this off.
	bool optimize_rectangles = true; // No reason to turn this off.
};

/// Optional: tweak ImGui style to make it render faster.
void make_style_fast();

/// Undo what make_style_fast did.
void restore_style();

/// Call once a the start of your program.
void bind_imgui_painting();

/// The buffer is assumed to follow how ImGui packs pixels, i.e. ABGR by default.
/// Change with IMGUI_USE_BGRA_PACKED_COLOR.
/// If width/height differs from ImGui::GetIO().DisplaySize then
/// the function scales the UI to fit the given pixel buffer.
void paint_imgui(uint32_t* pixels, int width_pixels, int height_pixels, const SwOptions& options = {});

/// Free the resources allocated by bind_imgui_painting.
void unbind_imgui_painting();

/// Show ImGui controls for rendering options if you want to.
bool show_options(SwOptions* io_options);

/// Show rendering stats in an ImGui window if you want to.
void show_stats();

void show_stats_in_terminal();
   
} // namespace imgui_sw
