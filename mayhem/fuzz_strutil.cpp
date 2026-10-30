// libFuzzer harness over nchat's StrUtil text helpers (lib/ncutil): the first input byte selects
// the function, the rest is its input.
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "strutil.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* p_Data, size_t p_Size)
{
  if (p_Size < 1) return -1;
  const uint8_t sel = p_Data[0] % 12;
  const std::string str(reinterpret_cast<const char*>(p_Data) + 1, p_Size - 1);

  switch (sel)
  {
    case 0:
      StrUtil::Emojize(str, true);
      StrUtil::Emojize(str, false);
      break;
    case 1:
      StrUtil::Textize(str);
      StrUtil::ToFold(str);
      break;
    case 2:
      StrUtil::EscapeRawUrls(str);
      break;
    case 3:
      StrUtil::ExtractUrlsFromStr(str);
      break;
    case 4:
    {
      std::string s = str;
      StrUtil::SanitizeMessageStr(s);
      StrUtil::Trim(s);
      break;
    }
    case 5:
    {
      const std::string hex = StrUtil::StrToHex(str);
      if (StrUtil::StrFromHex(hex) != str) __builtin_trap();
      StrUtil::StrFromHex(str);
      StrUtil::StrFromOct(str);
      break;
    }
    case 6:
    {
      const std::vector<std::string> parts = StrUtil::Split(str, ',');
      StrUtil::Join(parts, ",");
      StrUtil::ExtractString(str, "<", ">");
      break;
    }
    case 7:
    {
      const std::wstring wstr = StrUtil::ToWString(str);
      StrUtil::ToString(wstr);
      StrUtil::ToLower(wstr);
      StrUtil::WStringWidth(wstr);
      break;
    }
    case 8:
    {
      const std::wstring wstr = StrUtil::ToWString(str);
      std::wstring prefix, line;
      StrUtil::GetQuotePrefix(wstr, prefix, line);
      StrUtil::TrimPadWString(wstr, static_cast<int>(p_Size % 64));
      break;
    }
    case 9:
    case 10:
    case 11:
    {
      if (p_Size < 3) return -1;
      const unsigned lineLen = 1 + (p_Data[1] % 80);
      const uint8_t flags = p_Data[2];
      const std::wstring wstr = StrUtil::ToWString(std::string(reinterpret_cast<const char*>(p_Data) + 3, p_Size - 3));
      const int tab = (flags >> 4) % 9;
      if (sel == 9)
      {
        StrUtil::WordWrap(wstr, lineLen, flags & 1, flags & 2, flags & 4, tab);
      }
      else
      {
        int wrapLine = 0, wrapPos = 0;
        const int pos = static_cast<int>(p_Data[1] % (wstr.size() + 1));
        StrUtil::WordWrap(wstr, lineLen, flags & 1, flags & 2, flags & 4, tab, pos, wrapLine, wrapPos);
      }
      break;
    }
  }

  return 0;
}
