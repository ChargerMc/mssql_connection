import Cocoa
import FlutterMacOS

// This is a dummy plugin class required by Flutter's plugin registration system.
// The actual FFI bindings are handled by Dart FFI directly loading the
// bundled FreeTDS dynamic libraries.
public class MssqlConnectionPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // No method channel needed - this is an FFI plugin.
    // FreeTDS symbols are loaded dynamically via DynamicLibrary.open()
  }
}
