import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/legal_docs.dart';
import '../constants/public_routes.dart';
import '../widgets/common/url_modal_dialog.dart';

class LegalDocumentView extends StatefulWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDoc document;

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  Future<String>? _documentFuture;
  String? _loadedLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant LegalDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _documentFuture = null;
      _ensureLoaded();
    }
  }

  void _ensureLoaded() {
    final languageCode = context.locale.languageCode;
    if (_documentFuture == null || _loadedLanguageCode != languageCode) {
      _loadedLanguageCode = languageCode;
      _documentFuture = LegalDocs.load(widget.document, languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, icon, routeBadge, otherDocLink) = switch (widget.document) {
      LegalDoc.privacy => (
        'common.privacy_notice'.tr(),
        Icons.privacy_tip_outlined,
        PublicRoutes.privacy,
        UrlModalLink(
          label: 'common.terms_of_service'.tr(),
          location: PublicRoutes.terms,
        ),
      ),
      LegalDoc.terms => (
        'common.terms_of_service'.tr(),
        Icons.gavel_outlined,
        PublicRoutes.terms,
        UrlModalLink(
          label: 'common.privacy_notice'.tr(),
          location: PublicRoutes.privacy,
        ),
      ),
    };

    return UrlModalDialog(
      title: title,
      icon: icon,
      routeBadge: routeBadge,
      footerLinks: [otherDocLink],
      child: FutureBuilder<String>(
        future: _documentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('legal.load_error'.tr());
          }
          final text = snapshot.data;
          if (text == null) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _LegalDocumentBody(content: text);
        },
      ),
    );
  }
}

class _LegalDocumentBody extends StatelessWidget {
  const _LegalDocumentBody({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final baseStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final boldStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    );
    final headingStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
      height: 1.4,
    );
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
      height: 1.35,
    );

    final blocks = content
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList();

    final spans = <InlineSpan>[];
    for (var i = 0; i < blocks.length; i++) {
      final line = blocks[i];
      if (line.isEmpty) continue;
      if (spans.isNotEmpty) {
        final isHeading = line.startsWith('##');
        spans.add(TextSpan(text: isHeading ? '\n\n' : '\n'));
        final prevLine = i > 0 ? blocks[i - 1] : '';
        if (!isHeading && prevLine.isEmpty) {
          spans.add(const TextSpan(text: '\n')); // l10n-ignore
        }
      }

      if (line.startsWith('### ')) {
        spans.add(TextSpan(text: line.substring(4), style: headingStyle));
      } else if (line.startsWith('## ')) {
        spans.add(TextSpan(text: line.substring(3), style: titleStyle));
      } else if (line.startsWith('* ') || line.startsWith('- ')) {
        spans.add(TextSpan(text: '• ', style: boldStyle));
        spans.addAll(
          _parseInlineSpans(
            line.substring(2).trimLeft(),
            baseStyle: baseStyle,
            boldStyle: boldStyle,
          ),
        );
      } else {
        spans.addAll(
          _parseInlineSpans(line, baseStyle: baseStyle, boldStyle: boldStyle),
        );
      }
    }

    return SelectionArea(
      child: Text.rich(TextSpan(style: baseStyle, children: spans)),
    );
  }

  static List<InlineSpan> _parseInlineSpans(
    String text, {
    required TextStyle? baseStyle,
    required TextStyle? boldStyle,
  }) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*([^*]+)\*\*');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }
}
