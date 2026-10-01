import 'context_test.dart' as context_test;
import 'controller_test.dart' as controller_test;
import 'extensions_test.dart' as extensions_test;
import 'guards_edge_test.dart' as guards_edge_test;
import 'guards_test.dart' as guards_test;
import 'observer_edge_test.dart' as observer_edge_test;
import 'observer_test.dart' as observer_test;
import 'pages_edge_test.dart' as pages_edge_test;
import 'route_test.dart' as route_test;
import 'routes_edge_test.dart' as routes_edge_test;
import 'tabs_edge_test.dart' as tabs_edge_test;
import 'tabs_test.dart' as tabs_test;
import 'view_test.dart' as view_test;

void main() {
  route_test.main();
  controller_test.main();
  guards_test.main();
  extensions_test.main();
  observer_test.main();
  view_test.main();
  context_test.main();
  tabs_test.main();
  guards_edge_test.main();
  observer_edge_test.main();
  pages_edge_test.main();
  routes_edge_test.main();
  tabs_edge_test.main();
}
