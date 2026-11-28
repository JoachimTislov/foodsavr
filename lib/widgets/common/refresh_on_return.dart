import 'package:flutter/widgets.dart';

/// Calls [onReturn] when [child] becomes visible again, such as a kept-alive
/// navigation tab or a route that was covered, so data changed elsewhere does
/// not stay on screen.
class RefreshOnReturn extends StatefulWidget {
  final VoidCallback onReturn;
  final Widget child;

  const RefreshOnReturn({
    super.key,
    required this.onReturn,
    required this.child,
  });

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn> {
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden tabs and covered routes run with tickers disabled.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _visible == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReturn();
      });
    }
    _visible = visible;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
