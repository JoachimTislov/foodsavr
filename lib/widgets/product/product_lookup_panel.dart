import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../../services/open_food_facts_client.dart';
import '../../services/product_service.dart';
import '../../utils/barcode_validator.dart';
import 'barcode_feedback.dart';

/// Looks products up by barcode or by name, as many times as the user wants,
/// and lists the Open Food Facts candidates.
class ProductLookupPanel extends StatefulWidget {
  /// Looked up as soon as the panel appears, for example a scanned barcode.
  final String? initialQuery;

  /// The user picked one of the listed products.
  final ValueChanged<OffProductData> onCandidate;

  /// The user keeps a barcode that no listed product stands for.
  final ValueChanged<String> onKeepBarcode;
  final String keepBarcodeLabel;

  /// When set, a barcode that can be added straight away (already owned, known
  /// to Open Food Facts, or impossible to check) goes here without a list.
  final ValueChanged<String>? onBarcodeMatched;

  /// The button label while the input is a barcode; without one the panel is
  /// compact and the search button sits inside the field.
  final String? barcodeActionLabel;
  final FocusNode? focusNode;

  const ProductLookupPanel({
    super.key,
    this.initialQuery,
    required this.onCandidate,
    required this.onKeepBarcode,
    required this.keepBarcodeLabel,
    this.barcodeActionLabel,
    this.onBarcodeMatched,
    this.focusNode,
  });

  @override
  State<ProductLookupPanel> createState() => _ProductLookupPanelState();
}

class _ProductLookupPanelState extends State<ProductLookupPanel>
    with AutomaticKeepAliveClientMixin {
  static const _minNameLength = 2;
  static final _numeric = RegExp(r'^[0-9]+$');

  final _controller = TextEditingController();
  bool _loading = false;

  /// Drops answers to a query the user has since changed.
  int _sequence = 0;
  ProductLookupResult? _result;

  /// The barcode behind [_result]; null for a name search.
  String? _resultBarcode;

  /// The controller also reports selection changes; only new text resets.
  String _lastText = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery case final query?) {
      _controller.text = query;
      _lastText = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookUp();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _text => _controller.text.trim();

  /// The input as a barcode, or null when it is a name.
  String? get _barcodeInput {
    final normalized = BarcodeValidator.normalize(_text);
    return _numeric.hasMatch(normalized) ? normalized : null;
  }

  bool get _canLookUp {
    if (_loading) return false;
    final barcode = _barcodeInput;
    return barcode != null
        ? BarcodeValidator.isUsable(barcode)
        : _text.length >= _minNameLength;
  }

  void _onChanged(String value) {
    if (value == _lastText) return;
    setState(() {
      _lastText = value;
      _sequence++;
      _loading = false;
      _result = null;
    });
  }

  Future<void> _lookUp() async {
    if (!_canLookUp) return;
    final barcode = _barcodeInput;
    final query = _text;
    final sequence = ++_sequence;
    setState(() {
      _loading = true;
      _result = null;
    });
    final result = await _find(query, barcode);
    if (!mounted || sequence != _sequence) return;

    final matched = widget.onBarcodeMatched;
    final addable =
        result == null || result.exact || result.owned || result.offline;
    if (barcode != null && matched != null && addable) {
      setState(() => _loading = false);
      matched(barcode);
      return;
    }
    setState(() {
      _loading = false;
      _result = result ?? const ProductLookupResult(offline: true);
      _resultBarcode = barcode;
    });
  }

  /// Null when the lookup could not run at all.
  Future<ProductLookupResult?> _find(String query, String? barcode) async {
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'nb';
    try {
      final service = getIt<ProductService>();
      if (barcode == null) {
        return await service.searchCatalog(query, languageCode: languageCode);
      }
      return await service.lookupByBarcode(
        userId: getIt<IAuthService>().getUserId(),
        barcode: barcode,
        languageCode: languageCode,
      );
    } catch (error) {
      debugPrint('Product lookup failed: $error');
      return null;
    }
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _lastText = '';
      _result = null;
    });
  }

  /// What to say about [result], or null when its candidates speak.
  String? _outcomeMessage(ProductLookupResult result) {
    if (result.offline) return 'product.lookup.offline'.tr();
    if (result.owned) return 'product.lookup.owned'.tr();
    final barcode = _resultBarcode;
    if (barcode != null && !result.exact) {
      return 'product.lookup.noBarcodeMatch'.tr(
        namedArgs: {'barcode': barcode},
      );
    }
    return result.candidates.isEmpty ? 'product.lookup.noResults'.tr() : null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final barcode = _barcodeInput;
    final result = _result;
    final actionLabel = widget.barcodeActionLabel;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'product.lookup.field'.tr(),
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: actionLabel != null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'product.lookup.search'.tr(),
                    onPressed: _canLookUp ? _lookUp : null,
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: (_) => _lookUp(),
        ),
        if (barcode != null) ...[
          const SizedBox(height: Material3Config.spacing8),
          BarcodeFeedback(
            validity: BarcodeValidator.validate(barcode).validity,
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: Material3Config.spacing8),
          FilledButton(
            onPressed: _canLookUp ? _lookUp : null,
            child: Text(
              barcode != null || _text.isEmpty
                  ? actionLabel
                  : 'product.lookup.search'.tr(),
            ),
          ),
        ],
        if (_loading) ...[
          const SizedBox(height: Material3Config.spacing8),
          const LinearProgressIndicator(),
        ],
        if (result != null) ...[
          const SizedBox(height: Material3Config.spacing8),
          if (_outcomeMessage(result) case final message?)
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(message, style: mutedStyle),
            ),
          if (_resultBarcode case final kept? when !result.exact) ...[
            const SizedBox(height: Material3Config.spacing8),
            OutlinedButton.icon(
              onPressed: () {
                _reset();
                widget.onKeepBarcode(kept);
              },
              icon: const Icon(Icons.add),
              label: Text(widget.keepBarcodeLabel),
            ),
          ],
          if (result.candidates.isNotEmpty) ...[
            const SizedBox(height: Material3Config.spacing8),
            Text(
              'product.lookup.results'.tr(),
              style: theme.textTheme.titleSmall,
            ),
            for (final candidate in result.candidates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const ExcludeSemantics(
                  child: Icon(Icons.shopping_bag_outlined),
                ),
                title: Text(candidate.name ?? candidate.barcode ?? ''),
                subtitle: switch ([?candidate.brand, ?candidate.barcode]) {
                  [] => null,
                  final details => Text(details.join(' · ')),
                },
                onTap: () {
                  _reset();
                  widget.onCandidate(candidate);
                },
              ),
          ],
        ],
      ],
    );
  }
}
