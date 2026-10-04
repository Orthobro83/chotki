#ifndef CHOTKI_WINDOWS_UI_H
#define CHOTKI_WINDOWS_UI_H
#include <stdint.h>
typedef void (*ChotkiEvent)(void *context, int32_t control, int32_t event);
int32_t ch_run(ChotkiEvent callback, void *context, int32_t automated);
void ch_clear(void);
void ch_control(int32_t id, int32_t kind, const char *text, int32_t x, int32_t y, int32_t width, int32_t height);
void ch_list_add(int32_t id, const char *text);
void ch_update(int32_t id, const char *text);
int32_t ch_selected(int32_t id);
void ch_select(int32_t id, int32_t index);
int32_t ch_text(int32_t id, char *buffer, int32_t length);
int32_t ch_click(int32_t id);
int32_t ch_checked(int32_t id);
void ch_check(int32_t id, int32_t checked);
void ch_enable(int32_t id, int32_t enabled);
void ch_choose(int32_t id, int32_t index);
void ch_command(int32_t id);
void ch_rule_menu(int32_t paused, int32_t dispensed);
int32_t ch_capture(const char *path);
void ch_close(int32_t exitCode);
void ch_exit(int32_t code);
void ch_error(const char *message);
// 1 selected, 0 cancelled, -1 dialog/encoding error. Paths are UTF-8.
int32_t ch_file_dialog(int32_t save, const char *suggested, char *path, int32_t length);
// Synthetic chooser responses are accepted only by the automated review window.
void ch_test_file_dialog(const char *path, int32_t result);
void ch_post(int32_t control, int32_t event);
void ch_pump(void);
int32_t ch_width(void);
int32_t ch_height(void);
int32_t ch_font(const char *path);
int32_t ch_reading_face(char *buffer, int32_t length);
void ch_style(int32_t id, int32_t flags);
void ch_home_begin(int32_t x, int32_t y, int32_t width, int32_t height, int32_t contentHeight);
void ch_home_end(void);
void ch_cards_begin(int32_t x, int32_t y, int32_t width, int32_t height, int32_t contentWidth);
void ch_cards_end(void);
void ch_card(int32_t id, const char *title, const char *summary, const char *category,
             const char *time, const char *attribution, int32_t x, int32_t width, int32_t height);
void ch_image(int32_t id, const char *path, const char *quote, const char *source,
              double focusX, double focusY, int32_t x, int32_t y, int32_t width, int32_t height);
void ch_reset_home_scroll(void);
void ch_test_resize(int32_t width, int32_t height);
void ch_track_reading(int32_t id, int32_t token);
void ch_test_scroll_end(int32_t id, int32_t deliberate);
int32_t ch_first_visible_line(int32_t id);
#endif
