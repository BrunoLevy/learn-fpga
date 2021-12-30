// dear imgui: "null" example application
// (compile and link imgui, create context, run headless with NO INPUTS, NO GRAPHICS OUTPUT)
// This is useful to test building, but you cannot interact with anything here!
#include "imgui.h"
#include "imgui_sw.h"

extern "C" {
#include "lite_fb.h"
}

#include <stdio.h>

#include <libbase/uart.h>
#include <libbase/console.h>

#include <generated/csr.h>

void* operator new(size_t size) {
   return ImGui::MemAlloc(size);
}


int main(int, char**)
{
    printf("Initializing framebuffer...\n");
    fb_init();
    fb_set_dual_buffering(1);
   
    printf("Initializing ImGui...\n");
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();

    imgui_sw::bind_imgui_painting();
    imgui_sw::make_style_fast();
   
    printf("Starting ImGui...\n");
   
    int n = 0;
    for (;;) {
        ++n;
        io.DisplaySize = ImVec2(640, 480);
        io.DeltaTime = 1.0f / 60.0f;
        ImGui::NewFrame();

        ImGui::ShowDemoWindow(NULL);
       
        ImGui::SetNextWindowSize(ImVec2(150, 100));
        ImGui::Begin("Test");
        ImGui::Text("Hello, world!");
        ImGui::Text("Frame: %d",n);       
        ImGui::End();
       
        /*
        static float f = 0.0f;
        ImGui::Text("Hello, world!");
        ImGui::SliderFloat("float", &f, 0.0f, 1.0f);
        ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);
        */

        ImGui::Render();
        imgui_sw::paint_imgui((uint32_t*)fb_base,640,480);
        fb_swap_buffers();
        fb_clear();

        if (readchar_nonblock()) {
	   getchar();
	   break;;
        }
    }

    printf("DestroyContext()\n");
    ImGui::DestroyContext();
    return 0;
}
