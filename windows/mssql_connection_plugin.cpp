// This is a dummy plugin implementation required by Flutter's plugin system.
// The actual FFI bindings are handled by Dart FFI directly loading the
// bundled FreeTDS DLLs.

#include "include/mssql_connection/mssql_connection_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

void MssqlConnectionPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
    // No method channel needed - this is an FFI plugin.
    // FreeTDS DLLs are loaded dynamically via DynamicLibrary.open()
}
