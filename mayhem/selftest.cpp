// Known-answer checks over nchat's StrUtil helpers, built with the project's normal flags and run by
// mayhem/test.sh. Prints one "SELFTEST_PASS <name>" line per passing case so a neutered program
// (which prints nothing) is detected.
#include <iostream>
#include <string>
#include <vector>

#include "strutil.h"

static int s_Fail = 0;

#define CHECK_EQ(name, a, b)                                                       \
  do                                                                               \
  {                                                                                \
    if ((a) == (b)) std::cout << "SELFTEST_PASS " << name << std::endl;            \
    else { std::cout << "SELFTEST_FAIL " << name << std::endl; ++s_Fail; }         \
  } while (0)

int main()
{
  typedef std::vector<std::string> Strs;
  typedef std::vector<std::wstring> WStrs;

  CHECK_EQ("starts_with", StrUtil::StartsWith("hello world", "hello"), true);
  CHECK_EQ("starts_with_no", StrUtil::StartsWith("hello world", "world"), false);
  CHECK_EQ("split", StrUtil::Split("a,b,,c", ','), (Strs{ "a", "b", "", "c" }));
  CHECK_EQ("join", StrUtil::Join(Strs{ "x", "y", "z" }, "-"), std::string("x-y-z"));
  CHECK_EQ("to_hex", StrUtil::StrToHex("AB\x01"), std::string("414201"));
  CHECK_EQ("from_hex", StrUtil::StrFromHex("414201"), std::string("AB\x01"));
  CHECK_EQ("to_lower", StrUtil::ToLower(std::string("MiXeD 123")), std::string("mixed 123"));
  CHECK_EQ("is_integer", StrUtil::IsInteger("12345"), true);
  CHECK_EQ("is_integer_no", StrUtil::IsInteger("12a45"), false);
  CHECK_EQ("to_integer", StrUtil::ToInteger("-42"), -42L);
  CHECK_EQ("replace", ([] { std::string s = "aXbXc"; StrUtil::ReplaceString(s, "X", "--"); return s; }()),
           std::string("a--b--c"));
  CHECK_EQ("trim", ([] { std::string s = "   pad me  "; StrUtil::Trim(s); return s; }()), std::string("pad me"));
  CHECK_EQ("extract_string", StrUtil::ExtractString("key=<value>;", "<", ">"), std::string("value"));
  CHECK_EQ("extract_urls", StrUtil::ExtractUrlsFromStr("see https://example.com/a and http://foo.org/b?x=1 ok"),
           (Strs{ "https://example.com/a", "http://foo.org/b?x=1" }));
  CHECK_EQ("wstring_roundtrip", StrUtil::ToString(StrUtil::ToWString("plain ascii")), std::string("plain ascii"));
  CHECK_EQ("wordwrap", StrUtil::WordWrap(L"the quick brown fox jumps over the lazy dog", 20, false, false, false, 4),
           (WStrs{ L"the quick brown fox", L"jumps over the lazy", L"dog" }));
  CHECK_EQ("wordwrap_empty", StrUtil::WordWrap(L"", 20, false, false, false, 4).size(), size_t(0));
  CHECK_EQ("quote_prefix", ([] { std::wstring p, l; bool r = StrUtil::GetQuotePrefix(L">> hi", p, l);
                                 return r && p == L">> " && l == L"hi"; }()), true);

  return s_Fail == 0 ? 0 : 1;
}
