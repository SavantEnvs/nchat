// libFuzzer harness over TDLib's text-entity detection and parsing (pure functions in
// td/telegram/MessageEntity.cpp, vendored under lib/tgchat/ext/td). Generalises the in-tree
// lib/tgchat/ext/td/test/fuzz_url.cpp; the first input byte selects the function.
#include "td/telegram/MessageEntity.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/utf8.h"

#include <cstddef>
#include <cstdint>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t *data, std::size_t size) {
  if (size < 1) {
    return -1;
  }
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL));
  td::string text(reinterpret_cast<const char *>(data) + 1, size - 1);
  if (!td::check_utf8(text)) {
    return -1;
  }
  td::Slice slice(text);

  switch (data[0] % 10) {
    case 0:
      td::find_urls(slice);
      break;
    case 1:
      td::find_entities(slice, false, false);
      break;
    case 2:
      td::find_mentions(slice);
      td::find_bot_commands(slice);
      td::find_hashtags(slice);
      td::find_cashtags(slice);
      break;
    case 3:
      td::find_bank_card_numbers(slice);
      td::find_ton_addresses(slice);
      td::find_tg_urls(slice);
      break;
    case 4:
      td::is_email_address(slice);
      td::find_media_timestamps(slice);
      break;
    case 5:
      td::parse_markdown(text);
      break;
    case 6:
      td::parse_markdown_v2(text);
      break;
    case 7:
      td::parse_html(text);
      break;
    case 8: {
      td::FormattedText formatted;
      formatted.text = text;
      td::parse_markdown_v3(std::move(formatted));
      break;
    }
    case 9: {
      td::FormattedText formatted;
      formatted.text = text;
      td::get_markdown_v3(std::move(formatted));
      break;
    }
  }
  return 0;
}
