// This is a dummy plugin implementation required by Flutter's plugin system.
// The actual FFI bindings are handled by Dart FFI directly loading the
// bundled FreeTDS shared libraries.

#include "include/mssql_connection/mssql_connection_plugin.h"

#include <flutter_linux/flutter_linux.h>

#define MSSQL_CONNECTION_PLUGIN(obj)                                       \
    (G_TYPE_CHECK_INSTANCE_CAST((obj), mssql_connection_plugin_get_type(), \
                                MssqlConnectionPlugin))

struct _MssqlConnectionPlugin
{
    GObject parent_instance;
};

G_DEFINE_TYPE(MssqlConnectionPlugin, mssql_connection_plugin, g_object_get_type())

static void mssql_connection_plugin_dispose(GObject *object)
{
    G_OBJECT_CLASS(mssql_connection_plugin_parent_class)->dispose(object);
}

static void mssql_connection_plugin_class_init(MssqlConnectionPluginClass *klass)
{
    G_OBJECT_CLASS(klass)->dispose = mssql_connection_plugin_dispose;
}

static void mssql_connection_plugin_init(MssqlConnectionPlugin *self) {}

void mssql_connection_plugin_register_with_registrar(
    FlPluginRegistrar *registrar)
{
    // No method channel needed - this is an FFI plugin.
    // FreeTDS shared libraries are loaded dynamically via DynamicLibrary.open()
}
