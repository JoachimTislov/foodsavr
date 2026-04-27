import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:foodsavr/widgets/common/app_refresh_indicator.dart';
import 'package:foodsavr/widgets/common/error_state_widget.dart';
import 'package:foodsavr/main.dart';

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

  /// Optional error message to display when loading fails.
  final String? errorMessage;

  const RetryScaffold({
    super.key,
    required this.body,
    required this.onRefresh,
    this.maxRetries = 3,
    this.appBar,
    this.floatingActionButton,
    this.isBodyScrollable = true,
    this.fetchOnInit = true,
    this.errorMessage,
  });

  @override
  State<RetryScaffold> createState() => _RetryScaffoldState();
}

class _RetryScaffoldState extends State<RetryScaffold> {
  int _retryCount = 0;
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    globalRetryNotifier.addListener(_onGlobalRetry);
    if (widget.fetchOnInit) {
      _isLoading = true;
      // Use addPostFrameCallback to avoid calling setState during build if onRefresh is extremely fast
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRefresh();
      });
    }
  }

  @override
  void dispose() {
    globalRetryNotifier.removeListener(_onGlobalRetry);
    super.dispose();
  }

  Future<void> _onGlobalRetry() async {
    if (!mounted) return;
    if (_error != null && !_isLoading) {
      await _resetAndRetry();
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
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retryCount++;
          _error = e;
          _hasLoadedOnce = true;
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

  Future<void> _resetAndRetry() async {
    setState(() {
      _retryCount = 0;
    });
    await _handleRefresh();
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
    if (_isLoading && !_hasLoadedOnce) {
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
              ErrorStateWidget(
                message:
                    widget.errorMessage ?? 'common.maximumRetriesReached'.tr(),
                details: 'common.checkConnection'.tr(),
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
                label: Text('common.tryAgain'.tr()),
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
                widget.errorMessage ?? 'common.somethingWentWrong'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'common.attemptOf'.tr(
                  namedArgs: {
                    'current': _retryCount.toString(),
                    'total': widget.maxRetries.toString(),
                  },
                ),
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
                label: Text('common.tryAgain'.tr()),
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
