import 'package:flutter/material.dart';
import 'package:foodsavr/widgets/common/app_refresh_indicator.dart';
import 'package:foodsavr/widgets/common/error_state_widget.dart';

/// A scaffold that wraps a view with built-in retry logic, pull-to-refresh,
/// and error state management.
class RetryScaffold extends StatefulWidget {
  /// The main content to display on success.
  final Widget body;

  /// The async callback to fetch data.
  final Future<void> Function() onRefresh;

  /// Maximum allowed retry attempts before showing the final error state.
  final int maxRetries;

  /// Optional AppBar for the scaffold.
  final PreferredSizeWidget? appBar;

  /// Optional FloatingActionButton for the scaffold.
  final Widget? floatingActionButton;

  /// Whether the [body] provides its own scrolling.
  /// If false, it will be wrapped so pull-to-refresh works.
  final bool isBodyScrollable;

  /// Whether to automatically call [onRefresh] during initState.
  final bool fetchOnInit;

  const RetryScaffold({
    super.key,
    required this.body,
    required this.onRefresh,
    this.maxRetries = 3,
    this.appBar,
    this.floatingActionButton,
    this.isBodyScrollable = true,
    this.fetchOnInit = true,
  });

  @override
  State<RetryScaffold> createState() => _RetryScaffoldState();
}

class _RetryScaffoldState extends State<RetryScaffold> {
  int _retryCount = 0;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.fetchOnInit) {
      _isLoading = true;
      // Use addPostFrameCallback to avoid calling setState during build if onRefresh is extremely fast
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRefresh();
      });
    }
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;

    // Only set loading state if not already loading,
    // prevents UI jumps if called multiple times rapidly
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _retryCount = 0;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retryCount++;
          _error = e;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetAndRetry() {
    setState(() {
      _retryCount = 0;
    });
    _handleRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Initial loading state (only show spinner if it's the very first attempt)
    if (_isLoading && _retryCount == 0 && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle error states
    if (_error != null) {
      if (_retryCount >= widget.maxRetries) {
        // Final Failure State
        return AppRefreshIndicator(
          onRefresh: _handleRefresh,
          isScrollable: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ErrorStateWidget(
                message: 'Maximum retries reached',
                details: 'Please check your connection and try again later.',
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _resetAndRetry,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        );
      } else {
        // Intermediate Retry State
        return AppRefreshIndicator(
          onRefresh: _handleRefresh,
          isScrollable: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Attempt $_retryCount of ${widget.maxRetries}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleRefresh,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    }

    // Success State
    return AppRefreshIndicator(
      onRefresh: _handleRefresh,
      isScrollable: widget.isBodyScrollable,
      child: widget.body,
    );
  }
}
