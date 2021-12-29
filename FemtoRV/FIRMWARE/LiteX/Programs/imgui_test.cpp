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

void* operator new(size_t size) {
   return ImGui::MemAlloc(size);
}


int main(int, char**)
{
    fb_init();
   
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();

    imgui_sw::bind_imgui_painting();
    imgui_sw::make_style_fast();
   
   
    for (int n = 0; n < 5; n++) {
        printf("=========> NewFrame() %d\n", n);
        io.DisplaySize = ImVec2(640, 480);
        io.DeltaTime = 1.0f / 60.0f;
        ImGui::NewFrame();


        ImGui::SetNextWindowSize(ImVec2(320, 200));
        ImGui::Begin("Test");
        // ImGui::Text("Hello, world!");
        ImGui::End();
       
        /*
        static float f = 0.0f;
        ImGui::Text("Hello, world!");
        ImGui::SliderFloat("float", &f, 0.0f, 1.0f);
        ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);
        */

        //ImGui::ShowDemoWindow(NULL);	   
        ImGui::Render();
        imgui_sw::paint_imgui((uint32_t*)FB_BASE,640,480);
        imgui_sw::show_stats_in_terminal();
       
        flush_l2_cache(); // needed for femtorv32 + LiteX (L2 cache -> framebuffer transfer)
    }

    printf("DestroyContext()\n");
    ImGui::DestroyContext();
    return 0;
}
