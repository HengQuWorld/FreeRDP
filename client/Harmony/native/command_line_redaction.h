#ifndef FREERDP_HARMONY_COMMAND_LINE_REDACTION_H
#define FREERDP_HARMONY_COMMAND_LINE_REDACTION_H

#include <cctype>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

// Credentials must never become observable outside the process. They used to
// travel in the FreeRDP command line (/p:<password> and
// /gateway:...,p:<password>), which put the plaintext password into hilog and
// into user visible error strings. The session no longer builds those
// arguments, but anything that is still logged goes through these helpers so a
// future switch that carries a secret cannot silently leak it again.

namespace freerdp_harmony {

constexpr const char* kRedactedValue = "***";

// Case-insensitive check that `text` starts with `option`; valueOffset receives
// the length of the matched option so callers can keep the switch name.
inline bool MatchesOptionPrefix(const std::string& text, const char* option,
                                std::size_t& valueOffset) {
  const std::size_t optionLength = std::strlen(option);
  if (text.size() < optionLength) {
    return false;
  }
  for (std::size_t i = 0; i < optionLength; ++i) {
    if (std::tolower(static_cast<unsigned char>(text[i])) !=
        std::tolower(static_cast<unsigned char>(option[i]))) {
      return false;
    }
  }
  valueOffset = optionLength;
  return true;
}

inline std::string RedactArgument(const std::string& argument) {
  static const char* const kPasswordOptions[] = { "/p:", "-p:", "--password:", "/password:" };
  for (const char* option : kPasswordOptions) {
    std::size_t valueOffset = 0;
    if (MatchesOptionPrefix(argument, option, valueOffset)) {
      return argument.substr(0, valueOffset) + kRedactedValue;
    }
  }

  // /gateway:g:<host>,u:<user>,d:<domain>,p:<password>
  std::size_t gatewayOffset = 0;
  if (!MatchesOptionPrefix(argument, "/gateway:", gatewayOffset)) {
    return argument;
  }

  std::string redacted = argument.substr(0, gatewayOffset);
  std::size_t fieldStart = gatewayOffset;
  bool firstField = true;
  while (fieldStart <= argument.size()) {
    std::size_t fieldEnd = argument.find(',', fieldStart);
    if (fieldEnd == std::string::npos) {
      fieldEnd = argument.size();
    }
    if (!firstField) {
      redacted += ',';
    }
    firstField = false;

    const std::string field = argument.substr(fieldStart, fieldEnd - fieldStart);
    std::size_t passwordOffset = 0;
    if (MatchesOptionPrefix(field, "p:", passwordOffset)) {
      // A password may itself contain commas, so the field boundary cannot be
      // trusted: drop everything from here on rather than guess where it ends.
      redacted += field.substr(0, passwordOffset) + kRedactedValue;
      return redacted;
    }
    redacted += field;

    if (fieldEnd >= argument.size()) {
      break;
    }
    fieldStart = fieldEnd + 1;
  }
  return redacted;
}

inline std::string RedactCommandLine(const std::vector<std::string>& args) {
  std::string result;
  for (const std::string& arg : args) {
    if (!result.empty()) {
      result += ' ';
    }
    result += RedactArgument(arg);
  }
  return result;
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_COMMAND_LINE_REDACTION_H
