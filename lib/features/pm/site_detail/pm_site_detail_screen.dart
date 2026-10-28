import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PmSiteDetailScreen extends ConsumerWidget {
  final String siteId;
  const PmSiteDetailScreen({super.key, required this.siteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Site Detail: $siteId'),
      ),
      body: Center(
        child: Text('PM Site Detail Screen for site $siteId'),
      ),
    );
  }
}
