#include "command_line_redaction.h"

#include <iostream>
#include <string>
#include <vector>

namespace {

int failures = 0;

void ExpectEqual(const std::string& label, const std::string& actual,
                 const std::string& expected) {
  if (actual == expected) {
    std::cout << "OK   [" << label << "]: " << actual << "\n";
    return;
  }
  std::cout << "FAIL [" << label << "]: expected \"" << expected << "\", got \"" << actual
            << "\"\n";
  ++failures;
}

void ExpectUnchanged(const std::string& argument) {
  ExpectEqual(argument, freerdp_harmony::RedactArgument(argument), argument);
}

void ExpectRedacted(const std::string& argument, const std::string& expected,
                    const std::string& secret) {
  const std::string redacted = freerdp_harmony::RedactArgument(argument);
  ExpectEqual(argument, redacted, expected);
  if (!secret.empty() && redacted.find(secret) != std::string::npos) {
    std::cout << "FAIL [" << argument << "]: secret still present in \"" << redacted << "\"\n";
    ++failures;
  }
}

}  // namespace

int main() {
  // Password switches, every spelling the FreeRDP command line accepts.
  ExpectRedacted("/p:Passw0rd~!@", "/p:***", "Passw0rd");
  ExpectRedacted("-p:Passw0rd", "-p:***", "Passw0rd");
  ExpectRedacted("--password:Passw0rd", "--password:***", "Passw0rd");
  ExpectRedacted("/password:Passw0rd", "/password:***", "Passw0rd");
  ExpectRedacted("/P:Passw0rd", "/P:***", "Passw0rd");
  ExpectRedacted("/p:", "/p:***", "");

  // Gateway credentials: only the p: field is a secret, and it is treated as
  // reaching to the end of the argument because a password can contain commas.
  ExpectRedacted("/gateway:g:gw.example.com,u:alice,d:AD,p:S3cr3t,smartcard",
                 "/gateway:g:gw.example.com,u:alice,d:AD,p:***", "S3cr3t");
  ExpectRedacted("/gateway:g:gw.example.com,p:S3cr3t", "/gateway:g:gw.example.com,p:***",
                 "S3cr3t");
  ExpectRedacted("/gateway:g:gw.example.com,p:S3cr3t,", "/gateway:g:gw.example.com,p:***",
                 "S3cr3t");
  ExpectEqual("/gateway:g:gw.example.com,u:alice",
              freerdp_harmony::RedactArgument("/gateway:g:gw.example.com,u:alice"),
              "/gateway:g:gw.example.com,u:alice");

  // A password that itself looks like an option must not confuse the splitter.
  ExpectRedacted("/gateway:g:gw,p:a,b:p:c", "/gateway:g:gw,p:***", "a,b:p:c");

  // Ordinary arguments stay readable: they are what makes a log useful.
  ExpectUnchanged("/v:rdp.example.com");
  ExpectUnchanged("/port:3389");
  ExpectUnchanged("/u:alice");
  ExpectUnchanged("/d:AD");
  ExpectUnchanged("/sec:nla,tls,rdp");
  ExpectUnchanged("/gdi:sw");
  ExpectUnchanged("/size:1920x1080");
  ExpectUnchanged("freerdp-harmony");
  ExpectUnchanged("/drive:share,/sdcard/share");

  // Whole command line, as it is written to hilog.
  const std::vector<std::string> args = {
    "freerdp-harmony", "/gdi:sw",         "/v:rdp.example.com", "/port:3389",
    "/u:alice",        "/p:Passw0rd~!@",  "/sec:nla,tls,rdp",   "/smart-sizing",
  };
  const std::string expected =
      "freerdp-harmony /gdi:sw /v:rdp.example.com /port:3389 /u:alice /p:*** "
      "/sec:nla,tls,rdp /smart-sizing";
  ExpectEqual("command line", freerdp_harmony::RedactCommandLine(args), expected);
  if (freerdp_harmony::RedactCommandLine(args).find("Passw0rd") != std::string::npos) {
    std::cout << "FAIL [command line]: password still present\n";
    ++failures;
  }

  std::cout << "\n" << (failures == 0 ? "ALL PASSED" : "SOME FAILED") << ": " << failures
            << " failures\n";
  return failures == 0 ? 0 : 1;
}
