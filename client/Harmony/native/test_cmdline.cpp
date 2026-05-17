#include <freerdp/client.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/settings.h>
#include <stdio.h>
#include <vector>
#include <string>
#include <iostream>

static int test_case(const std::vector<std::string>& args, const char* label) {
    rdpSettings* settings = freerdp_settings_new(0);
    std::vector<char*> argv;
    for (auto& arg : args) {
        argv.push_back(&arg[0]);
    }

    int rc = freerdp_client_settings_parse_command_line(settings, argv.size(), argv.data(), FALSE);
    if (rc < 0) {
        printf("FAIL [%s]: parse returned %d\n", label, rc);
        freerdp_settings_free(settings);
        return 1;
    }

    BOOL gfx = freerdp_settings_get_bool(settings, FreeRDP_SupportGraphicsPipeline);
    BOOL swGdi = freerdp_settings_get_bool(settings, FreeRDP_SoftwareGdi);
    BOOL multi = freerdp_settings_get_bool(settings, FreeRDP_SupportMultitransport);
    printf("OK   [%s]: GFX=%d SoftwareGdi=%d Multitransport=%d\n", label, gfx, swGdi, multi);
    freerdp_settings_free(settings);
    return 0;
}

int main() {
    int failures = 0;

    // Test 1: GFX ON (the default Win10+ path) with multitransport disabled
    failures += test_case({
        "freerdp-harmony",
        "/v:127.0.0.1:3389",
        "/gdi:sw",
        "-clipboard",
        "/audio-mode:2",
        "/cert:ignore",
        "/gfx",
        "/network:auto",
        "-multitransport",
        "/dynamic-resolution",
        "/bpp:32",
    }, "gfx-on-no-udp");

    // Test 2: GFX OFF (the Win11 fallback path) with multitransport disabled
    failures += test_case({
        "freerdp-harmony",
        "/v:127.0.0.1:3389",
        "/gdi:sw",
        "-clipboard",
        "/audio-mode:2",
        "/cert:ignore",
        "/network:auto",
        "-multitransport",
        "/dynamic-resolution",
        "/bpp:32",
    }, "gfx-off-no-udp");

    // Test 3: Default FreeRDP (multitransport ON by default — baseline)
    failures += test_case({
        "freerdp-harmony",
        "/v:127.0.0.1:3389",
    }, "default-baseline");

    printf("\n%s: %d failures\n", failures == 0 ? "ALL PASSED" : "SOME FAILED", failures);
    return failures;
}
