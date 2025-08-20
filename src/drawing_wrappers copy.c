// Wrapper functions to bridge C test suite with ASM implementations

#include "include/visual_types.h"

// ASM function declarations (with single underscore as they appear in object files)
extern void _set_pixel_asm(uint32_t *pixels, int x, int y, uint32_t color);
extern void _clear_frame_asm(uint32_t *pixels, uint32_t color);
extern void _draw_circle_filled_asm(uint32_t *pixels, int cx, int cy, int radius, uint32_t color);
extern uint32_t _circle_color_asm(float base_hue, float saturation, float value);
extern color_t* _hsv_to_rgb(hsv_t *hsv, color_t *output);
extern uint32_t _color_to_pixel(color_t *color);

// C wrapper functions (remove underscore for C linking)
void set_pixel_asm(uint32_t *pixels, int x, int y, uint32_t color) {
    _set_pixel_asm(pixels, x, y, color);
}

void clear_frame_asm(uint32_t *pixels, uint32_t color) {
    _clear_frame_asm(pixels, color);
}

void draw_circle_filled_asm(uint32_t *pixels, int cx, int cy, int radius, uint32_t color) {
    _draw_circle_filled_asm(pixels, cx, cy, radius, color);
}

uint32_t circle_color_asm(float base_hue, float saturation, float value) {
    return _circle_color_asm(base_hue, saturation, value);
}

color_t* hsv_to_rgb(hsv_t *hsv, color_t *output) {
    return _hsv_to_rgb(hsv, output);
}

uint32_t color_to_pixel(color_t *color) {
    return _color_to_pixel(color);
}
