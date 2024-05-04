#pragma once

#include <gui/gui.h>
#include <gui/icon_i.h>
#include <furi.h>
#include <furi_hal_memory.h>
#include <furi_hal_random.h>

void furi_log_non_variadic(FuriLogLevel level, const char *tag, const char *string) {
  furi_log_print_format(level, tag, "%s", string);
}
