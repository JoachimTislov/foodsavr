import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/legal_docs.dart';

class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDoc document;

  @override
  Widget build(BuildContext context) {
    final title = switch (document) {
      LegalDoc.privacy => 'common.privacy_notice'.tr(),
      LegalDoc.terms => 'common.terms_of_service'.tr(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: context.canPop()
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => context.go('/'),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder(
            future: LegalDocs.load(document, context.locale.languageCode),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('legal.load_error'.tr());
              }
              final text = snapshot.data;
              if (text == null) return const CircularProgressIndicator();
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SelectableText(text),
              );
            },
          ),
        ),
      ),
    );
  }
}
