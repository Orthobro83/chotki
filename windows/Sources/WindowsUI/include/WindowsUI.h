#ifndef CHOTKI_WINDOWS_UI_H
#define CHOTKI_WINDOWS_UI_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*ChotkiEvent)(void *context, int32_t control, int32_t event);
int32_t ch_run(ChotkiEvent callback, void *context, int32_t automated);
enum { CH_TRAY_OPEN = 7000, CH_TRAY_TOGGLE, CH_TRAY_SETTINGS, CH_TRAY_QUIT };
void ch_tray_geometry(const double *knots, int32_t count, const double *bars, int32_t rectangles, const double *foot);
void ch_tray_enabled(int32_t enabled);
void ch_opening_geometry(const double *knots,int32_t count,const double *bars,int32_t rectangles,const double *foot);
int32_t ch_test_opening_frame(double milliseconds);
int32_t ch_tray_present(void);
void ch_foreground(void);
void ch_start_hidden(int32_t hidden);
void ch_review_mode(int32_t review);
int32_t ch_opening_active(void);
void ch_lifecycle_review(int32_t enabled);
int32_t ch_single_instance(void);
int32_t ch_sound_prepare(const unsigned char *tick,int32_t tickLength,const unsigned char *bell,int32_t bellLength,int32_t review);
int32_t ch_sound_play(int32_t bell);
int32_t ch_test_sound(int32_t bell);
void ch_sound_close(void);
int32_t ch_notifications_start(int32_t mode);
int32_t ch_notification_show(const char *identifier,const char *title,const char *body);
int32_t ch_notification_cancel(const char *identifier);
int32_t ch_notification_take(int32_t ticket,char *identifier,int32_t length,char *action,int32_t actionLength);
int32_t ch_test_notification(const char *identifier,const char *action);
int32_t ch_notification_history_count(void);
void ch_notifications_close(void);
void ch_taskbar(int32_t visible);
int32_t ch_startup(int32_t enabled);
int32_t ch_test_startup(void);
int32_t ch_test_tray(int32_t command);
int32_t ch_test_window(int32_t operation);
void ch_rich_style(int32_t id, int32_t start, int32_t length, int32_t flags, int32_t size, int32_t linkID);
void ch_rich_finish(int32_t id);
void ch_reader_dividers(int32_t id);
void ch_rich_center(int32_t id);
void ch_remove(int32_t id);
void ch_focus(int32_t id);
void ch_glossary_resize(int32_t x, int32_t y, int32_t width, int32_t height);
int32_t ch_test_link_key(int32_t id);
int32_t ch_test_reader_identity(int32_t id);
void ch_glossary_begin(int32_t x, int32_t y, int32_t width, int32_t height);
void ch_glossary_close(void);
int32_t ch_open_url(const char *url);
int32_t ch_test_link(int32_t id, int32_t index);
int32_t ch_test_reader_painted(int32_t id);
int32_t ch_test_rich_flags(int32_t id, int32_t start);
void ch_flush(void);
void ch_clear(void);
void ch_render_begin(void);
void ch_transition(int32_t sidebar);
void ch_calendar_browse(int32_t active);
void ch_render_end(void);
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
void ch_rule_menu(int32_t paused, int32_t dispensed, int32_t kept, int32_t expanded, int32_t about, const char *destination);
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
void ch_attention(int32_t id,int32_t milliseconds);
int32_t ch_test_attention(int32_t id);
void ch_font_size(int32_t id,int32_t size,int32_t serif,int32_t bold);
void ch_rope_update(int32_t id, int32_t count, int32_t target);
void ch_prayer_keys(int32_t enabled);
void ch_choice_add(int32_t id, const char *title, const char *group, int32_t index);
void ch_choice_popup(int32_t id);
int32_t ch_test_space(int32_t id, int32_t repeat);
int32_t ch_test_space_modifier(int32_t id, int32_t modifier);
int32_t ch_test_prayer_menu(int32_t id);
void ch_home_begin(int32_t x, int32_t y, int32_t width, int32_t height, int32_t contentHeight);
void ch_home_end(void);
void ch_cards_begin(int32_t x, int32_t y, int32_t width, int32_t height, int32_t contentWidth);
void ch_cards_end(void);
void ch_reveal_card(int32_t id);
int32_t ch_test_card_revealed(int32_t id);
void ch_card(int32_t id, const char *title, const char *summary, const char *category,
             const char *time, const char *attribution, int32_t x, int32_t width, int32_t height);
void ch_image(int32_t id, const char *path, const char *quote, const char *source,
              double focusX, double focusY, int32_t x, int32_t y, int32_t width, int32_t height);
void ch_reset_home_scroll(void);
void ch_home_content(int32_t height);
int32_t ch_rich_fit(int32_t id);
void ch_test_panel_scroll(int32_t bottom);
void ch_test_panel_wheel(int32_t turns);
int32_t ch_test_reader_wheel(int32_t id,int32_t turns);
int32_t ch_test_reader_wheel_delta(int32_t id,int32_t delta,int32_t repeats);
int32_t ch_test_reader_first_line(int32_t id);
int32_t ch_test_reader_paint_count(int32_t id);
void ch_show(int32_t id,int32_t visible);
void ch_library_hover(int32_t anchor,int32_t firstLink,int32_t count,int32_t height);
int32_t ch_test_library_hover(int32_t firstLink,int32_t active);
void ch_test_calendar_expire(void);
int32_t ch_test_control_visible(int32_t id);
int32_t ch_test_control_intersects(int32_t id);
int32_t ch_measure_text(const char *text, int32_t width, int32_t flags);
int32_t ch_measure_reading(const char *text, int32_t width, int32_t size);
int32_t ch_report_begin(void);
int32_t ch_report_height(void);
void ch_report_end(int32_t show);
int32_t ch_report_visible(void);
int32_t ch_test_report(int32_t operation);
int32_t ch_capture_report(const char *path);
void ch_test_resize(int32_t width, int32_t height);
void ch_track_reading(int32_t id, int32_t token);
void ch_track_reading_range(int32_t id, int32_t end, int32_t token);
void ch_reader_scroll_line(int32_t id, int32_t line);
void ch_test_scroll_character(int32_t id, int32_t position, int32_t deliberate);
void ch_test_scroll_end(int32_t id, int32_t deliberate);
int32_t ch_first_visible_line(int32_t id);
#ifdef __cplusplus
}
#endif
#endif
